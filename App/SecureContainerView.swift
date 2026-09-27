import UIKit

/// 安全渲染层：全屏 isSecureTextEntry UITextField。
///
/// 结论（多轮实机验证）：iOS 系统层面，「内容正常可见」与「全 App 截屏变黑」不可兼得——
/// 黑化需要系统识别「可见的安全内容」，而可见内容必然遮挡界面；激活 secure 字段会引出
/// 屏幕底部输入提示条的副作用。传纸条能做到靠的是私有副作用，无法在二进制层面可靠复刻。
///
/// 因此本层**不激活、空文本、透明、穿透**，对界面零副作用（无遮挡、无底部提示条、不拦输入）。
/// 截屏黑化放弃；确定有效的防泄露由配套承担：录屏检测全屏覆盖（UIScreen.isCaptured 实测可黑）、
/// 截屏/录屏上报对端、通讯阅后即焚不落地。
final class SecureContainerView: UITextField {

    /// 不激活：避免弹输入提示条、避免抢焦点卡输入
    override var canBecomeFirstResponder: Bool { false }

    init() {
        super.init(frame: .zero)
        isSecureTextEntry = true
        borderStyle = .none
        backgroundColor = .clear
        textColor = .clear
        text = ""
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 安全层完全不参与触摸：一律穿透到下层内容，绝不拦截任何点击。
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
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
        let bg = UIColor(white: 0.06, alpha: 1)
        view.backgroundColor = bg

        // 底层：secure 安全层（不激活、空文本、穿透，对界面零副作用）
        let s = SecureContainerView()
        s.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(s)
        NSLayoutConstraint.activate([
            s.topAnchor.constraint(equalTo: view.topAnchor),
            s.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            s.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            s.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // 上层：真实内容，不透明深色背景 → 所有页面内容正常显示。
        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        content.view.backgroundColor = bg
        view.addSubview(content.view)
        NSLayoutConstraint.activate([
            content.view.topAnchor.constraint(equalTo: view.topAnchor),
            content.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        content.didMove(toParent: self)
    }

    override var shouldAutorotate: Bool { content.shouldAutorotate }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { content.supportedInterfaceOrientations }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
