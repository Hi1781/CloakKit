import UIKit

/// 安全渲染容器：透明 UITextField（isSecureTextEntry），整页内容挂进字段内部。
///
/// 对齐传纸条（逆向自其 `SecureContainerView.swift` + `setSecureTextEntry`）机制：
/// - 内容作为子视图 addSubview 到 UITextField 本身（布局稳定）；
/// - 字段保持**激活（first responder）**启动系统对 secure 字段的截图保护渲染；
/// - hitTest 让字段自身**穿透**，不拦截触摸 → 密码框/搜索/聊天输入框仍可正常点击聚焦；
/// - 真实输入框聚焦时让安全字段让位（避免抢焦点导致无法输入），输入完抢回激活。
///
/// ⚠️ 诚实边界：iOS 的 secure 截图保护主要作用于字段自身，能否把挂载的普通子视图整块黑化
/// 取决于系统实现且随大版本变化（传纸条同样依赖这一副作用）。配套：录屏检测黑屏 + 阅后即焚
/// 不落地 + 截屏上报对端威慑。翻拍、越狱无法防范。
final class SecureContainerView: UITextField {

    /// 允许成为第一响应者以激活 secure 保护通道；空 inputView 规避弹键盘
    override var canBecomeFirstResponder: Bool { true }

    init() {
        super.init(frame: .zero)
        isSecureTextEntry = true
        borderStyle = .none
        backgroundColor = .clear
        // 占位安全字形，扩大系统对 secure 字段的保护范围（透明，正常显示不可见）
        textColor = .clear
        font = UIFont.systemFont(ofSize: 300)
        text = String(repeating: "●", count: 40)
        inputView = UIView(frame: .zero)
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
    private var secure: SecureContainerView?

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
        secure = s

        addChild(content)
        s.embed(content.view)
        content.didMove(toParent: self)

        // 真实输入框聚焦时让安全字段让位（避免抢焦点），输入完短暂抢回以持续激活保护
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(inputBegan),
                       name: UITextField.textDidBeginEditingNotification, object: nil)
        nc.addObserver(self, selector: #selector(inputEnded),
                       name: UITextField.textDidEndEditingNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        secure?.becomeFirstResponder()
    }

    @objc private func inputBegan() {
        secure?.resignFirstResponder()
    }
    @objc private func inputEnded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.secure?.becomeFirstResponder()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        secure?.resignFirstResponder()
    }

    override var shouldAutorotate: Bool { content.shouldAutorotate }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { content.supportedInterfaceOrientations }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
