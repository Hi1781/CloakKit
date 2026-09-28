import UIKit
import UniformTypeIdentifiers
import PhotosUI
import AVFoundation

/// 模块6 · 去中心化私密通讯（会话列表）
/// 「我的」Peer ID / 邀请码；联系人 + 群聊；消息本地持久化（真实 P2P 层后置）
final class MessagingViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let table = UITableView(frame: .zero, style: .insetGrouped)
    private var store = ChatStore.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "私密通讯"
        GlassTheme.installScene(on: view)
        table.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let add = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addContact))
        let group = UIBarButtonItem(image: UIImage(systemName: "person.3"), style: .plain,
                                    target: self, action: #selector(addGroup))
        navigationItem.rightBarButtonItems = [add, group]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        table.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ScreenGuard.chatAppeared()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ScreenGuard.chatDisappeared()
    }

    // MARK: - 我的 Peer ID
    @objc private func showMyCard() {
        let id = store.myPeerID, invite = store.myInvite
        let a = UIAlertController(title: "我的身份", message: "Peer ID：\(id)\n邀请码：\(invite)\n\n复制给好友即可建立加密会话。", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "复制邀请码", style: .default) { _ in
            UIPasteboard.general.string = "邀请码：\(invite)｜PeerID：\(id)"
        })
        a.addAction(UIAlertAction(title: "关闭", style: .cancel))
        present(a, animated: true)
    }

    @objc private func addContact() {
        let a = UIAlertController(title: "新联系人", message: "输入对方 Peer ID / 邀请码", preferredStyle: .alert)
        a.addTextField { $0.placeholder = "peer:xxx… / PTK-XXXXXX" }
        a.addAction(UIAlertAction(title: "添加", style: .default) { [weak self] _ in
            let t = a.textFields?.first?.text ?? ""
            guard !t.isEmpty else { return }
            self?.store.addPeer("新联系人", invite: t, isGroup: false)
            self?.table.reloadData()
        })
        a.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(a, animated: true)
    }

    @objc private func addGroup() {
        let a = UIAlertController(title: "创建群聊", message: "群名称", preferredStyle: .alert)
        a.addTextField { $0.placeholder = "群名称" }
        a.addAction(UIAlertAction(title: "创建", style: .default) { [weak self] _ in
            let t = a.textFields?.first?.text ?? "新群聊"
            self?.store.addPeer(t.isEmpty ? "新群聊" : t, invite: "group:" + UUID().uuidString.prefix(8).lowercased(), isGroup: true)
            self?.table.reloadData()
        })
        a.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(a, animated: true)
    }

    // MARK: - Table
    func numberOfSections(in tableView: UITableView) -> Int { 3 }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["我的", "群聊", "联系人"][section]
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return store.peers.filter { $0.isGroup }.count
        default: return store.peers.filter { !$0.isGroup }.count
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        if indexPath.section == 0 {
            c.textLabel?.text = "我的 Peer ID / 邀请码"
            c.textLabel?.textColor = GlassTheme.tint
            c.detailTextLabel?.text = "\(store.myPeerID)"
            c.detailTextLabel?.textColor = .systemGray2
            c.imageView?.image = UIImage(systemName: "person.crop.circle.badge.checkmark")
            c.imageView?.tintColor = GlassTheme.tint
            GlassTheme.glassCell(on: c)
            return c
        }
        let peers = indexPath.section == 1 ? store.peers.filter { $0.isGroup } : store.peers.filter { !$0.isGroup }
        let p = peers[indexPath.row]
        c.textLabel?.text = p.name
        c.textLabel?.textColor = .white
        c.detailTextLabel?.text = p.lastText
        c.detailTextLabel?.textColor = .systemGray2
        c.imageView?.image = UIImage(systemName: p.isGroup ? "person.3.fill" : "person.crop.circle")
        c.imageView?.tintColor = p.isGroup ? .systemPurple : GlassTheme.tint
        GlassTheme.glassCell(on: c)
        return c
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 { showMyCard(); return }
        let peers = indexPath.section == 1 ? store.peers.filter { $0.isGroup } : store.peers.filter { !$0.isGroup }
        let chat = ChatViewController()
        chat.peer = peers[indexPath.row]
        navigationController?.pushViewController(chat, animated: true)
    }
}
