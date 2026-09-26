import UIKit
import UniformTypeIdentifiers
import MultipeerConnectivity

/// 模块7 · 文件局域网高速互传（MultipeerConnectivity 真实传输）
final class FileTransferViewController: UITableViewController, UIDocumentPickerDelegate, LANTransferDelegate {

    private let lan = LANTransferManager.shared
    private var receivedFiles: [URL] = []
    private var pendingPeer: MCPeerID?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "文件互传"
        GlassTheme.installScene(on: view)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        lan.delegate = self
        lan.start()

        let refresh = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"),
                                      style: .plain, target: self, action: #selector(refreshTap))
        navigationItem.rightBarButtonItem = refresh
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadFiles()
        tableView.reloadData()
    }

    private func reloadFiles() {
        receivedFiles = (try? FileManager.default.contentsOfDirectory(
            at: lan.receivedDir, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])) ?? []
    }

    @objc private func refreshTap() { tableView.reloadData() }

    // MARK: - LAN delegate
    func lanPeersChanged() { tableView.reloadData() }
    func lanSendProgress(name: String, done: Int64, total: Int64) {
        title = "发送中 \(name)"
        tableView.reloadData()
    }
    func lanSendFinished() {
        title = "文件互传"
        tableView.reloadData()
    }
    func lanReceiveProgress(name: String, done: Int64, total: Int64) {
        title = "接收中 \(name)"
        tableView.reloadData()
    }
    func lanReceiveFinished(url: URL, name: String) {
        title = "文件互传"
        reloadFiles()
        tableView.reloadData()
        let a = UIAlertController(title: "接收完成", message: "已保存：\(name)", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "好", style: .default))
        present(a, animated: true)
    }

    // MARK: - 发送
    private func send(to peer: MCPeerID) {
        pendingPeer = peer
        let p = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        p.delegate = self
        p.allowsMultipleSelection = false
        present(p, animated: true)
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let peer = pendingPeer else { return }
        pendingPeer = nil
        lan.send(fileURL: url, to: peer)
    }

    // MARK: - Table
    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["局域网设备", "传输进度", "已接收文件"][section]
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return max(lan.discovered.count, 1)
        case 1: return 1
        default: return max(receivedFiles.count, 1)
        }
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        c.textLabel?.textColor = .white
        c.detailTextLabel?.textColor = .systemGray2
        GlassTheme.glassCell(on: c)
        switch indexPath.section {
        case 0:
            if lan.discovered.isEmpty {
                c.textLabel?.text = "正在搜索附近设备…"
                c.textLabel?.textColor = .systemGray2
                c.imageView?.image = nil
            } else {
                let d = lan.discovered[indexPath.row]
                c.textLabel?.text = d.name
                c.detailTextLabel?.text = "点击选择文件发送"
                c.imageView?.image = UIImage(systemName: "iphone.radiowaves.left.and.right")
                c.imageView?.tintColor = GlassTheme.tint
            }
        case 1:
            if let sp = lan.sendProgress {
                c.textLabel?.text = "发送：\(sp.name)"
                c.detailTextLabel?.text = "\(Self.kb(sp.done)) / \(Self.kb(sp.total)) KB"
            } else if let rp = lan.receiveProgress {
                c.textLabel?.text = "接收：\(rp.name)"
                c.detailTextLabel?.text = "\(Self.kb(rp.done)) / \(Self.kb(rp.total)) KB"
            } else {
                c.textLabel?.text = "空闲"
                c.detailTextLabel?.text = "在同 Wi-Fi 的 iPhone/iPad 上打开本 App 即可互传"
                c.textLabel?.textColor = .systemGray2
            }
        default:
            if receivedFiles.isEmpty {
                c.textLabel?.text = "暂无接收记录"
                c.textLabel?.textColor = .systemGray2
                c.imageView?.image = nil
            } else {
                let u = receivedFiles[indexPath.row]
                c.textLabel?.text = u.lastPathComponent
                let size = (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                c.detailTextLabel?.text = "\(Self.kb(Int64(size))) KB · 点击分享"
                c.imageView?.image = UIImage(systemName: "doc.fill")
                c.imageView?.tintColor = GlassTheme.tint
            }
        }
        return c
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0, !lan.discovered.isEmpty {
            send(to: lan.discovered[indexPath.row].peer)
        } else if indexPath.section == 2, !receivedFiles.isEmpty {
            let av = UIActivityViewController(activityItems: [receivedFiles[indexPath.row]], applicationActivities: nil)
            av.popoverPresentationController?.sourceView = view
            present(av, animated: true)
        }
    }

    private static func kb(_ n: Int64) -> Int { Int(Double(n) / 1024) }
}
