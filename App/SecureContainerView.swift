import UIKit

/// 安全渲染容器：透明 UITextField（isSecureTextEntry），整页内容挂进字段内部。
///
/// 对齐传纸条（逆向自其 `SecureContainerView.swift` + `setSecureTextEntry`）：
/// - 内容作为子视图 addSubview 到 UITextField 本身（不要挂私有 _UITextLayoutView——按文本
///   排版、frame 不可控，会把内容裁没、导致 UI 无法显示/输入）。
/// - 字段**不抢占第一响应者**（canBecomeFirstResponder=false），彻底保证真实输入框
///   （密码框/搜索/聊天）可点、可聚焦，修复“无法输入”问题。
///
/// ⚠️ 诚实边界：iOS 的 secure 渲染主要作用于字段自身，普通子视图能否被系统整块黑化
/// 取决于系统实现且随大版本变化；真正的“防泄露”靠配套：录屏检测黑屏 + 通讯阅后即焚
/// 内容不落地 + 截屏上报对端威慑（ScreenGuard / PrivacyThreatReporter 承担）。翻拍、越狱无法防范。
final class SecureContainerView: UITextField {

    /// 不抢焦点，避免盖层拦截真实输入框
    override var canBecomeFirstResponder: Bool { false }

    init() {
        super.init(frame: .zero)
        isSecureTextEntry = true
        borderStyle = .none
        backgroundColor = .clear
        textColor = .clear
        font = UIFont.systemFont(ofSize: 300)
        text = String(repeating: "●", count: 40)
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 字段自身不拦截触摸：命中自己则穿透到下层，命中内容子视图则正常交给内容
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    /// 把真实内容挂进字段内部（布局稳定）
    func embed(_ content: UIView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
}

/// 把任意根控制器（TabBar / 解锁页）的内容放进安全容器，整页防截屏
final class SecureWrapperViewController: UIViewController {
    private let content: UIViewController

    init(content: UIViewController) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)

        let s = SecureContainerView()
        s.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(s)
        NSLayoutConstraint.activate([
            s.topAnchor.constraint(equalTo: view.topAnchor),
            s.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            s.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            s.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        addChild(content)
        s.embed(content.view)
        content.didMove(toParent: self)
    }

    override var shouldAutorotate: Bool { content.shouldAutorotate }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { content.supportedInterfaceOrientations }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
