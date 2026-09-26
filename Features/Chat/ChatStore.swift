import UIKit

/// 通讯数据模型与本地持久化（联系人 / 群聊 / 消息）
struct ChatPeer: Codable, Equatable {
    var id: String
    var name: String
    var isGroup: Bool
    var invite: String      // 邀请码 / Peer ID
    var lastText: String = ""
}

struct ChatMessage: Codable {
    var id: String
    var peerId: String
    var kind: String        // text / image / file / audio / system
    var text: String = ""
    var fileName: String = ""
    var fromMe: Bool
    var time: String
    var burnAfter: Int?     // 阅后即焚：读后 N 秒销毁（nil/0 = 永久）；可选以便兼容旧数据
}

final class ChatStore {
    static let shared = ChatStore()

    var peers: [ChatPeer] = []
    var messages: [String: [ChatMessage]] = [:]

    var dir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Chat", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    var mediaDir: URL {
        let m = dir.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: m, withIntermediateDirectories: true)
        return m
    }

    /// 本机 Peer ID / 邀请码
    var myPeerID: String {
        if let s = UserDefaults.standard.string(forKey: "chat_my_id") { return s }
        let id = "peer:" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12).lowercased()
        UserDefaults.standard.set(id, forKey: "chat_my_id")
        return id
    }
    var myInvite: String {
        if let s = UserDefaults.standard.string(forKey: "chat_my_invite") { return s }
        let v = "PTK-" + String(UUID().uuidString.prefix(6).uppercased())
        UserDefaults.standard.set(v, forKey: "chat_my_invite")
        return v
    }

    init() {
        // 默认联系人
        peers = [
            ChatPeer(id: "p1", name: "匿名用户 A", isGroup: false, invite: "peer:8f2a…c41", lastText: "（端到端加密）"),
            ChatPeer(id: "p2", name: "匿名用户 B", isGroup: false, invite: "peer:3d9e…77b", lastText: "收到，密钥已交换"),
        ]
        load()
    }

    func addPeer(_ name: String, invite: String, isGroup: Bool) {
        let id = "p" + String(Date().timeIntervalSince1970)
        peers.insert(ChatPeer(id: id, name: name, isGroup: isGroup, invite: invite), at: 0)
        savePeers()
    }

    func addMessage(_ m: ChatMessage) {
        var arr = messages[m.peerId] ?? []
        arr.append(m)
        messages[m.peerId] = arr
        saveMessages()
        // 更新会话摘要
        if let i = peers.firstIndex(where: { $0.id == m.peerId }) {
            let label: String
            switch m.kind {
            case "image": label = "[图片]"
            case "file": label = "[文件] " + m.fileName
            case "audio": label = "[语音]"
            case "system": label = m.text
            default: label = m.text
            }
            peers[i].lastText = label
            savePeers()
        }
    }

    /// 删除某条消息（阅后即焚销毁用）
    func removeMessage(id: String, from peerId: String) {
        guard var arr = messages[peerId] else { return }
        arr.removeAll { $0.id == id }
        messages[peerId] = arr
        saveMessages()
    }

    /// 截屏/录屏威胁上报：给所有对端插入一条安全告警（威慑 + 溯源）
    func addThreatAlert(_ detail: String) {
        for p in peers {
            let m = ChatMessage(id: UUID().uuidString, peerId: p.id,
                                kind: "system", text: detail,
                                fileName: "", fromMe: false, time: Self.now(),
                                burnAfter: nil)
            var arr = messages[p.id] ?? []
            arr.append(m)
            messages[p.id] = arr
        }
        saveMessages()
    }

    private static func now() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: Date())
    }

    func copyMedia(_ from: URL, ext: String) -> URL? {
        let dest = mediaDir.appendingPathComponent(UUID().uuidString + "." + ext)
        do {
            let scoped = from.startAccessingSecurityScopedResource()
            defer { if scoped { from.stopAccessingSecurityScopedResource() } }
            try FileManager.default.copyItem(at: from, to: dest)
            return dest
        } catch {
            return nil
        }
    }

    // MARK: - 持久化
    private var peersURL: URL { dir.appendingPathComponent("peers.json") }
    private var msgsURL: URL { dir.appendingPathComponent("messages.json") }

    private func savePeers() {
        if let d = try? JSONEncoder().encode(peers) { try? d.write(to: peersURL) }
    }
    private func saveMessages() {
        if let d = try? JSONEncoder().encode(messages) { try? d.write(to: msgsURL) }
    }
    private func load() {
        if let d = try? Data(contentsOf: peersURL),
           let p = try? JSONDecoder().decode([ChatPeer].self, from: d) {
            peers = p
        }
        if let d = try? Data(contentsOf: msgsURL),
           let m = try? JSONDecoder().decode([String: [ChatMessage]].self, from: d) {
            messages = m
        }
    }
}
