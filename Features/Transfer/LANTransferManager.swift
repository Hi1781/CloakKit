import UIKit
import MultipeerConnectivity

protocol LANTransferDelegate: AnyObject {
    func lanPeersChanged()
    func lanSendProgress(name: String, done: Int64, total: Int64)
    func lanSendFinished()
    func lanReceiveProgress(name: String, done: Int64, total: Int64)
    func lanReceiveFinished(url: URL, name: String)
}

/// 局域网真实互传引擎（MultipeerConnectivity：自动发现 + 可靠传输）
/// 控制协议：首字节 'm'=元信息(JSON)  'c'=数据块  'e'=结束
final class LANTransferManager: NSObject {
    static let shared = LANTransferManager()

    weak var delegate: LANTransferDelegate?
    private(set) var discovered: [(peer: MCPeerID, name: String)] = []
    private(set) var sendProgress: (name: String, done: Int64, total: Int64)?
    private(set) var receiveProgress: (name: String, done: Int64, total: Int64)?

    private let serviceType = "ptktool-xfer"
    private let myID = MCPeerID(displayName: UIDevice.current.name + "-隐私工具箱")
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    private let chunkSize = 512 * 1024

    private var isSending = false
    private var sendFH: FileHandle?
    private var sendSize: Int64 = 0
    private var sendSent: Int64 = 0

    private var incoming: [String: (fh: FileHandle, size: Int64, got: Int64)] = [:]

    var receivedDir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LANReceived", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private override init() {
        super.init()
        session = MCSession(peer: myID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: myID,
                                               discoveryInfo: ["app": "privacy-toolkit"],
                                               serviceType: serviceType)
        advertiser.delegate = self
        browser = MCNearbyServiceBrowser(peer: myID, serviceType: serviceType)
        browser.delegate = self
    }

    func start() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }
    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    // MARK: - 发送
    func send(fileURL: URL, to peer: MCPeerID) {
        guard !isSending else { return }
        guard let fh = try? FileHandle(forReadingFrom: fileURL) else { return }
        let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let name = fileURL.lastPathComponent

        isSending = true
        sendFH = fh
        sendSize = Int64(size)
        sendSent = 0
        sendProgress = (name, 0, Int64(size))

        let meta: [String: Any] = ["cmd": "meta", "name": name, "size": size, "chunk": chunkSize]
        if let md = try? JSONSerialization.data(withJSONObject: meta),
           let first = String(data: md, encoding: .utf8) {
            var frame = Data("m".utf8)
            frame.append(Data(first.utf8))
            try? session.send(frame, toPeers: [peer], with: .reliable)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            while true {
                guard let data = try? fh.read(upToCount: self.chunkSize), !data.isEmpty else { break }
                var frame = Data("c".utf8)
                frame.append(data)
                try? self.session.send(frame, toPeers: [peer], with: .reliable)
                self.sendSent += Int64(data.count)
                let done = self.sendSent
                DispatchQueue.main.async {
                    self.sendProgress = (name, done, Int64(size))
                    self.delegate?.lanSendProgress(name: name, done: done, total: Int64(size))
                }
            }
            try? fh.close()
            var frame = Data("e".utf8)
            frame.append(Data(name.utf8))
            try? self.session.send(frame, toPeers: [peer], with: .reliable)
            DispatchQueue.main.async {
                self.isSending = false
                self.delegate?.lanSendFinished()
            }
        }
    }

    // MARK: - 接收处理
    private func handleFrame(_ data: Data, from peer: MCPeerID) {
        guard let tag = data.first else { return }
        let body = data.dropFirst()
        switch Character(UnicodeScalar(tag)) {
        case "m":
            if let s = String(data: body, encoding: .utf8),
               let meta = try? JSONSerialization.jsonObject(with: Data(s.utf8)) as? [String: Any],
               let name = meta["name"] as? String {
                let size = (meta["size"] as? Int) ?? 0
                let url = receivedDir.appendingPathComponent(name)
                try? FileManager.default.removeItem(at: url)
                let ok = FileManager.default.createFile(atPath: url.path, contents: nil)
                if let fh = ok ? try? FileHandle(forWritingTo: url) : nil {
                    incoming[name] = (fh, Int64(size), 0)
                    receiveProgress = (name, 0, Int64(size))
                    delegate?.lanReceiveProgress(name: name, done: 0, total: Int64(size))
                }
            }
        case "c":
            // 先找活跃的接收任务（用最近一个）
            guard let (name, entry) = incoming.first else { return }
            let fh = entry.fh
            do {
                try fh.seek(toOffset: UInt64(entry.got))
                try fh.write(contentsOf: body)
                var got = entry.got + Int64(body.count)
                if got > entry.size { got = entry.size }
                incoming[name] = (entry.fh, entry.size, got)
                receiveProgress = (name, got, entry.size)
                delegate?.lanReceiveProgress(name: name, done: got, total: entry.size)
            } catch { }
        case "e":
            if let name = String(data: body, encoding: .utf8), let entry = incoming.removeValue(forKey: name) {
                try? entry.fh.close()
                let url = receivedDir.appendingPathComponent(name)
                delegate?.lanReceiveFinished(url: url, name: name)
            }
        default: break
        }
    }
}

// MARK: - MCSessionDelegate
extension LANTransferManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in self?.delegate?.lanPeersChanged() }
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        handleFrame(data, from: peerID)
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - 广播 / 发现
extension LANTransferManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // 自动接受邀请
        invitationHandler(true, session)
    }
}
extension LANTransferManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        if !discovered.contains(where: { $0.peer == peerID }) {
            discovered.append((peerID, peerID.displayName))
        }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 20)
        DispatchQueue.main.async { [weak self] in self?.delegate?.lanPeersChanged() }
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        discovered.removeAll { $0.peer == peerID }
        DispatchQueue.main.async { [weak self] in self?.delegate?.lanPeersChanged() }
    }
}
