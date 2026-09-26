import UIKit

/// 安全渲染容器：透明 UITextField（isSecureTextEntry），内容挂进字段内部。
///
/// 最终定位（经多轮实机验证）：**iOS 的 secure 截图保护不会把挂载的普通子视图在截图时变黑**，
/// 无论字段是否激活都是如此。因此本容器**彻底放弃抢占第一响应者**，保证输入框 100% 可正常
/// 点击聚焦（这是反复出问题、最伤体验的点）。isSecureTextEntry 仅作尽力而为的保留，
/// 不承担“截图黑屏”承诺。
///
/// 真正确定有效的防泄露（由 ScreenGuard / 通讯阅后即焚承担）：
/// 1. 录屏/投屏检测（UIScreen.isCaptured）→ 全屏覆盖黑屏（录屏确实能黑）；
/// 2. 截屏/录屏 → 自动上报对端安全告警（威慑 + 溯源）；
/// 3. 通讯阅后即焚 → 内容读后销毁、本地不落地（截图截不到有价值内容）。
/// iOS 无公开 API 能让普通 App 视图截屏变黑，此为系统限制；翻拍、越狱亦无法防范。
final class SecureContainerView: UITextField {

    /// 不抢焦点，杜绝输入框被拦截
    override var canBecomeFirstResponder: Bool { false }

    init() {
        super.init(frame: .zero)
        isSecureTextEntry = true
        borderStyle = .none
        backgroundColor = .clear
        textColor = .clear
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

/// 把任意根控制器（TabBar / 解锁页）的内容放进安全容器
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
