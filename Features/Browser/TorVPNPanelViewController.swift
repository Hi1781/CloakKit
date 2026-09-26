import UIKit

/// 隐私浏览器 · 连接控制面板（复刻专业隐私浏览器 UI）
/// VPN 节点接入真实 SOCKS5 引擎（Socks5Client 真实握手/连通性探测）；
/// TOR 洋葱引擎 / 系统级 VPN 需额外集成，界面壳保留。
final class TorVPNPanelViewController: UIViewController {

    private let scroll = UIScrollView()
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        GlassTheme.installScene(on: view)
        title = "连接控制"
        build()
        statusLabel.text = Self.nodeSummary()
    }

    private func sectionTitle(_ t: String) -> UILabel {
        let l = UILabel()
        l.text = t
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = .white
        return l
    }

    private func sectionNote(_ t: String) -> UILabel {
        let l = UILabel()
        l.text = t
        l.font = .systemFont(ofSize: 12)
        l.textColor = .systemGray2
        l.numberOfLines = 0
        return l
    }

    private func row(_ title: String, _ on: Bool, _ tag: Int) -> (UIStackView, UISwitch) {
        let l = UILabel()
        l.text = title
        l.textColor = .white
        l.font = .systemFont(ofSize: 15)
        let sw = UISwitch()
        sw.isOn = on
        sw.tag = tag
        sw.addTarget(self, action: #selector(toggled(_:)), for: .valueChanged)
        let r = UIStackView(arrangedSubviews: [l, sw])
        r.axis = .horizontal
        r.distribution = .equalSpacing
        r.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return (r, sw)
    }

    private func actionBtn(_ t: String, _ tag: Int) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(t, for: .normal)
        b.tag = tag
        b.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        b.layer.borderWidth = 0.5
        b.layer.borderColor = GlassTheme.stroke.cgColor
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 8
        b.heightAnchor.constraint(equalToConstant: 44).isActive = true
        b.addTarget(self, action: #selector(actionTapped(_:)), for: .touchUpInside)
        return b
    }

    private func build() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32),
        ])

        // ---- VPN ----
        stack.addArrangedSubview(sectionTitle("VPN"))
        stack.addArrangedSubview(sectionNote("自定义节点全局代理。节点由你在设置中自行配置，应用不提供任何节点。"))
        let (v1, _) = row("Connect", false, 100)
        let (v2, _) = row("Connect on Launch", false, 101)
        let (v3, _) = row("Connect on Demand", false, 102)
        stack.addArrangedSubview(v1); stack.addArrangedSubview(v2); stack.addArrangedSubview(v3)
        let loc = actionBtn("节点 · 当前: 未选择", 200)
        stack.addArrangedSubview(loc)
        stack.addArrangedSubview(actionBtn("自定义节点配置", 201))

        // ---- TOR ----
        stack.addArrangedSubview(sectionTitle("TOR"))
        stack.addArrangedSubview(sectionNote("洋葱网络引擎。侧载环境需集成 Tor 核心库后真实生效，当前为界面壳。"))
        let (t1, _) = row("Connect", false, 110)
        let (t2, _) = row("Connect on Launch", false, 111)
        stack.addArrangedSubview(t1); stack.addArrangedSubview(t2)
        stack.addArrangedSubview(actionBtn("Location · 随机节点", 202))
        let (b1, _) = row("Bridges · 网桥", false, 112)
        stack.addArrangedSubview(b1)
        stack.addArrangedSubview(actionBtn("New Identity（新身份）", 203))

        // ---- Speed Boost ----
        stack.addArrangedSubview(sectionTitle("Speed Boost 加速"))
        stack.addArrangedSubview(sectionNote("普通网站走 VPN，洋葱域名自动切 TOR。"))
        let (s1, _) = row("启用混合加速", false, 120)
        stack.addArrangedSubview(s1)

        // ---- 底部操作 ----
        stack.addArrangedSubview(UIView()) // 弹性空隙
        stack.addArrangedSubview(sectionTitle("真实连接状态"))
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = .systemGray2
        statusLabel.numberOfLines = 0
        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(actionBtn("测试节点连通（真实 SOCKS5 握手）", 207))
        let status = actionBtn("Status · 连接状态", 204)
        stack.addArrangedSubview(status)
        stack.addArrangedSubview(actionBtn("Troubleshoot · 故障诊断", 205))
        stack.addArrangedSubview(actionBtn("Share Configuration · 分享配置", 206))
    }

    @objc private func toggled(_ sw: UISwitch) {
        UserDefaults.standard.set(sw.isOn, forKey: "vpn_toggle_\(sw.tag)")
        // VPN Connect 打开 → 对已保存节点做真实探测
        if sw.tag == 100 && sw.isOn { probeNode() }
        if sw.tag == 100 && !sw.isOn {
            statusLabel.text = Self.nodeSummary() + "（未连接）"
        }
    }

    /// 读取本地保存的节点，做真实 SOCKS5 探测
    private func probeNode() {
        guard let cfg = Self.firstNodeConfig() else {
            statusLabel.text = "未配置节点。请在「自定义节点配置」填写 SOCKS5 服务器地址与端口。"
            let a = UIAlertController(title: "没有节点", message: "请先添加自定义节点（SOCKS5 服务器）。", preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "好", style: .default))
            present(a, animated: true)
            return
        }
        statusLabel.text = "正在连接 \(cfg.host):\(cfg.port) …"
        Socks5Client.probe(cfg) { [weak self] ok, ms, err in
            guard let self = self else { return }
            if ok {
                self.statusLabel.text = "已通过节点建立链路 · \(String(format: "%.0fms", ms))\n节点：\(cfg.host):\(cfg.port)"
            } else {
                self.statusLabel.text = "连接失败 · \(err)\n节点：\(cfg.host):\(cfg.port)"
            }
        }
    }

    static func firstNodeConfig() -> Socks5Client.Config? {
        let list = UserDefaults.standard.stringArray(forKey: "vpn_nodes") ?? []
        guard let first = list.first else { return nil }
        let parts = first.components(separatedBy: "|")
        guard parts.count >= 3, let port = Int(parts[2]) else { return nil }
        return Socks5Client.Config(host: parts[1], port: port,
                                   user: "", pass: parts.count > 3 ? parts[3] : "")
    }

    static func nodeSummary() -> String {
        if let c = firstNodeConfig() { return "当前节点：\(c.host):\(c.port)" }
        return "当前节点：未配置"
    }

    @objc private func actionTapped(_ btn: UIButton) {
        switch btn.tag {
        case 200, 202:
            let alert = UIAlertController(title: "选择节点地区", message: nil, preferredStyle: .actionSheet)
            for c in ["Auto", "US", "DE", "JP", "HK", "SG", "自定义"] {
                alert.addAction(UIAlertAction(title: c, style: .default) { _ in
                    btn.setTitle("节点 · 当前: \(c)", for: .normal)
                })
            }
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            present(alert, animated: true)
        case 201:
            let vc = NodeConfigViewController()
            vc.modalPresentationStyle = .pageSheet
            present(vc, animated: true)
        case 203:
            let a = UIAlertController(title: "New Identity", message: "已请求更换洋葱身份链路（真实链路需 Tor 引擎）。", preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "好", style: .default))
            present(a, animated: true)
        case 204:
            probeNode()
        case 207:
            probeNode()
        case 205:
            let a = UIAlertController(title: "故障诊断",
                                      message: "· SOCKS5 节点引擎：真实可用，需自配节点\n· TOR 洋葱引擎：需集成 Tor 核心 C 库（侧载未集成）\n· 系统级 VPN：需 NetworkExtension entitlement + 签名描述文件（raw IPA 不支持）",
                                      preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "好", style: .default))
            present(a, animated: true)
        case 206:
            let text = "privacy-toolkit://vpn?host=&port=&proto=wireguard"
            let a = UIAlertController(title: "分享配置", message: text, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "复制", style: .default) { _ in
                UIPasteboard.general.string = text
            })
            a.addAction(UIAlertAction(title: "关闭", style: .cancel))
            present(a, animated: true)
        default:
            break
        }
    }
}

/// 自定义 VPN 节点配置（仅保存本地配置，不提供节点）
final class NodeConfigViewController: UIViewController, UITextFieldDelegate {
    private let hostField = UITextField()
    private let portField = UITextField()
    private let keyField = UITextField()
    private let nameField = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "自定义节点"
        view.backgroundColor = UIColor(white: 0.08, alpha: 1)
        build()
    }

    private func build() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        for (f, ph) in [(hostField, "服务器地址"), (portField, "端口"), (keyField, "密钥 / 密码"), (nameField, "节点备注")] {
            f.placeholder = ph
            f.backgroundColor = UIColor.white.withAlphaComponent(0.12)
            f.layer.borderWidth = 0.5
            f.layer.borderColor = GlassTheme.stroke.cgColor
            f.textColor = .white
            f.layer.cornerRadius = 8
            f.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 44))
            f.leftViewMode = .always
            f.heightAnchor.constraint(equalToConstant: 44).isActive = true
            stack.addArrangedSubview(f)
        }

        let saveBtn = UIButton(type: .system)
        saveBtn.setTitle("保存节点", for: .normal)
        saveBtn.backgroundColor = .systemBlue
        saveBtn.setTitleColor(.white, for: .normal)
        saveBtn.layer.cornerRadius = 8
        saveBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        saveBtn.addTarget(self, action: #selector(saveNode), for: .touchUpInside)
        stack.addArrangedSubview(saveBtn)

        let testBtn = UIButton(type: .system)
        testBtn.setTitle("测试连接（真实 SOCKS5 握手）", for: .normal)
        testBtn.setTitleColor(GlassTheme.tint, for: .normal)
        testBtn.addTarget(self, action: #selector(testNode), for: .touchUpInside)
        stack.addArrangedSubview(testBtn)

        testLabel.font = .systemFont(ofSize: 13)
        testLabel.textColor = .systemGray2
        testLabel.numberOfLines = 0
        stack.addArrangedSubview(testLabel)
    }

    private let testLabel = UILabel()

    @objc private func testNode() {
        let host = hostField.text ?? ""
        let port = Int(portField.text ?? "") ?? 0
        guard !host.isEmpty, port > 0 else {
            testLabel.text = "请填写服务器地址与端口"
            return
        }
        let key = keyField.text ?? ""
        testLabel.text = "正在连接 \(host):\(port) …"
        Socks5Client.probe(Socks5Client.Config(host: host, port: port, user: "", pass: key)) { [weak self] ok, ms, err in
            self?.testLabel.text = ok
                ? "连接成功 · \(String(format: "%.0fms", ms)) · 代理链路正常"
                : "失败：\(err)"
        }
    }

    @objc private func saveNode() {
        let host = hostField.text ?? ""
        guard !host.isEmpty else { return }
        var list = UserDefaults.standard.stringArray(forKey: "vpn_nodes") ?? []
        list.append("\(nameField.text ?? "节点")|\(host)|\(portField.text ?? "")|\(keyField.text ?? "")")
        UserDefaults.standard.set(list, forKey: "vpn_nodes")
        let a = UIAlertController(title: "已保存", message: "节点已加入本地列表（仅本机保存，不含真实代理服务）。", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "好", style: .default))
        present(a, animated: true)
    }
}
