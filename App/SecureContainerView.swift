import UIKit

/// 安全渲染层：全屏 isSecureTextEntry UITextField，照搬传纸条 SecureContainerView 机制。
///
/// 关键机制（从传纸条二进制逆向确认：SecureContainerView + setSecureTextEntry）：
/// 系统对「激活（first responder）的 isSecureTextEntry 字段」，在截屏/录屏时把整个字段
/// bounds 渲染为安全色块 → 全屏黑化。与字形是否可见无关（因此空文本即可，正常界面干净）。
///
/// 适配（保证正常可用）：
/// - 空文本 + 透明背景 → 正常界面完全不遮挡；
/// - inputView = 空视图 → 激活也不弹系统键盘；
/// - hitTest 一律穿透 → 不拦截任何触摸，输入框照常可点；
/// - 内容放在上层不透明层 → 各页面内容正常显示。
///
/// 诚实边界：此黑化是系统副作用，随 iOS 大版本可能失效；翻拍、越狱无法防范。
final class SecureContainerView: UITextField {

    /// 允许成为第一响应者（激活），以触发系统对 secure 字段的截图黑化
    override var canBecomeFirstResponder: Bool { true }

    init() {
        super.init(frame: .zero)
        isSecureTextEntry = true
        borderStyle = .none
        backgroundColor = .clear
        textColor = .clear
        text = ""
        // 空 inputView：激活时用空白视图替换系统键盘，避免弹键盘
        inputView = UIView(frame: .zero)
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
    private var secure: SecureContainerView?

    init(content: UIViewController) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let bg = UIColor(white: 0.06, alpha: 1)
        view.backgroundColor = bg

        // 底层：secure 安全层（isSecureTextEntry + 空文本透明）。激活后截屏黑化全屏。
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

        // 上层：真实内容，不透明深色背景 → 所有页面内容正常显示，不露出安全层。
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 激活 secure 字段，触发系统截图黑化（viewDidLoad 时窗口可能未就绪）
        if secure?.isFirstResponder != true {
            secure?.becomeFirstResponder()
        }
    }

    override var shouldAutorotate: Bool { content.shouldAutorotate }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { content.supportedInterfaceOrientations }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
