import UIKit

/// 免责声明页：首次使用需明确阅读并勾选同意，同意后进入主界面
final class DisclaimerViewController: UIViewController {

    private let agreeBtn = UIButton(type: .system)
    private var agreed = false

    private static let items: [(String, String)] = [
        ("本地数据", "本应用所有数据（含加密相册、通讯记录）仅存储于本机沙盒，不上传任何服务器。"),
        ("Tor / VPN", "内置 Tor 与 VPN 连接控制面板。节点由用户自行配置，本应用不提供、不运营任何代理节点服务。"),
        ("合规边界", "请在遵守所在地区法律法规的前提下使用。涉及跨境联网、规避网络监管等行为由使用者自行承担责任。"),
        ("隐私日志", "「隐私审计」读取系统记录 App 活动的隐私日志，仅用于本地查看与分析。"),
        ("侧载风险", "本应用为未上架、未签名安装包，仅限个人侧载使用，开发者不对第三方签名安装途径承担任何责任。"),
        ("功能声明", "Tor 真实联网需后续集成核心库，当前版本为界面呈现；实际连通能力以版本说明为准。"),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        GlassTheme.installScene(on: view)
        title = "免责声明"
        build()
    }

    private func build() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let head = UILabel()
        head.text = "使用前请阅读并同意以下声明"
        head.textColor = .white
        head.font = .systemFont(ofSize: 20, weight: .bold)
        head.numberOfLines = 0
        stack.addArrangedSubview(head)

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let list = UIStackView()
        list.axis = .vertical
        list.spacing = 10
        list.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(list)
        NSLayoutConstraint.activate([
            list.topAnchor.constraint(equalTo: scroll.topAnchor),
            list.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            list.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            list.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])
        for (t, d) in Self.items {
            let card = GlassTheme.glassCard(content: {
                let v = UIStackView()
                v.axis = .vertical
                v.spacing = 6
                let a = UILabel(); a.text = t; a.textColor = .white; a.font = .systemFont(ofSize: 16, weight: .semibold)
                let b = UILabel(); b.text = d; b.textColor = .systemGray2; b.font = .systemFont(ofSize: 13); b.numberOfLines = 0
                v.addArrangedSubview(a); v.addArrangedSubview(b)
                return v
            }(), radius: 16)
            list.addArrangedSubview(card)
        }
        scroll.heightAnchor.constraint(equalToConstant: 320).isActive = true
        stack.addArrangedSubview(scroll)

        let check = UIButton(type: .system)
        check.setImage(UIImage(systemName: "square"), for: .normal)
        check.setTitle("  我已阅读并同意上述声明", for: .normal)
        check.tintColor = .white
        check.setTitleColor(.white, for: .normal)
        check.addTarget(self, action: #selector(toggleAgree(_:)), for: .touchUpInside)
        stack.addArrangedSubview(check)

        agreeBtn.setTitle("同意并进入应用", for: .normal)
        agreeBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        agreeBtn.setTitleColor(.white, for: .normal)
        agreeBtn.backgroundColor = GlassTheme.tint.withAlphaComponent(0.5)
        agreeBtn.layer.cornerRadius = 24
        agreeBtn.isEnabled = false
        agreeBtn.addTarget(self, action: #selector(accept), for: .touchUpInside)
        agreeBtn.heightAnchor.constraint(equalToConstant: 48).isActive = true
        stack.addArrangedSubview(agreeBtn)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    @objc private func toggleAgree(_ btn: UIButton) {
        agreed.toggle()
        let name = agreed ? "checkmark.square.fill" : "square"
        btn.setImage(UIImage(systemName: name), for: .normal)
        btn.tintColor = agreed ? GlassTheme.tint : .white
        agreeBtn.isEnabled = agreed
        agreeBtn.backgroundColor = GlassTheme.tint.withAlphaComponent(agreed ? 1 : 0.5)
    }

    @objc private func accept() {
        UserDefaults.standard.set(true, forKey: "onboarded_v2")
        if let scene = view.window?.windowScene,
           let window = scene.windows.first {
            RootRouter.window = window
            RootRouter.resolve(in: window)
        }
    }
}
