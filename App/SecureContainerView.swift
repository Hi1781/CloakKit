import UIKit

/// 安全渲染层：全屏「激活态」isSecureTextEntry 输入框（底层黑幕）
///
/// 机制（照传纸条的推断结构，与你分析一致）：
///   - 底层放一个覆盖全屏、isSecureTextEntry = true 的输入框，**保持激活（第一响应者）**，
///     文本为覆盖全屏的黑色安全字形 → 系统在截图/录屏缓冲区把这段 secure 内容整体黑化，
///     从而「截图时整个屏幕变成黑色」。
///   - 顶层用不透明深色背景的真实界面完全盖住它 → 正常显示看不见黑幕、不拦触摸、不弹键盘。
///   - inputView / inputAccessoryView 置空 → 激活时不弹系统键盘；唯一副作用是 iOS 的
///     「密码自动填充」输入提示条（传纸条截图底部那条浅灰细线正是它）。
///   - 真实输入框获得焦点时 secure 自动失焦（正在输入时截图不黑），失焦后 wrapper 重新激活它。
final class SecureContainerView: UITextField {

    init() {
        super.init(frame: .zero)
        isSecureTextEntry = true
        borderStyle = .none
        backgroundColor = .black
        textColor = .black
        // 覆盖全屏的黑色安全字形，让系统在捕获时把整屏黑化
        text = String(repeating: "●", count: 900)
        textAlignment = .center
        font = .systemFont(ofSize: 44, weight: .bold)
        // 隐藏系统键盘（保持激活但不弹键盘）
        inputView = UIView()
        inputAccessoryView = UIView()
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 必须能成为第一响应者（激活 → 系统保留 secure 渲染 → 截屏黑化）
    override var canBecomeFirstResponder: Bool { true }

    /// 完全穿透：不拦截任何触摸，事件落到顶层内容
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }

    /// 保持激活；若刚被真实输入框抢走焦点，失焦后由 wrapper 重新激活
    func activate() {
        DispatchQueue.main.async { [weak self] in
            if !(self?.isFirstResponder ?? false) {
                _ = self?.becomeFirstResponder()
            }
        }
    }
}

/// 把任意根控制器（TabBar / 解锁页）的内容放进安全容器
final class SecureWrapperViewController: UIViewController {
    private let content: UIViewController
    private let secure: SecureContainerView
    private var fgObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?

    init(content: UIViewController) {
        self.content = content
        self.secure = SecureContainerView()
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let fgObserver { NotificationCenter.default.removeObserver(fgObserver) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let bg = UIColor(white: 0.06, alpha: 1)
        view.backgroundColor = bg

        // 底层：激活态 secure 黑幕（截图时整屏黑化）
        secure.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(secure)

        // 顶层：真实内容，不透明深色背景 → 正常显示时黑幕被完全盖住，看不到、不影响交互。
        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        content.view.backgroundColor = bg
        view.addSubview(content.view)
        NSLayoutConstraint.activate([
            secure.topAnchor.constraint(equalTo: view.topAnchor),
            secure.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            secure.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            secure.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            content.view.topAnchor.constraint(equalTo: view.topAnchor),
            content.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        content.didMove(toParent: self)

        // 前台 / 输入框失焦后，重新激活 secure 黑幕
        fgObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.secure.activate() }
        resignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.keyboardWillHideNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.secure.activate() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        secure.activate()
    }

    override var shouldAutorotate: Bool { content.shouldAutorotate }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { content.supportedInterfaceOrientations }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
