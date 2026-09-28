import UIKit

/// 防截屏容器：UITextLayoutCanvasView 私有画布方案（不激活键盘）
///
/// 机制（传纸条推断结构）：
///   - 创建一个 isSecureTextEntry = true 的 UITextField；
///   - 把它内部的私有内容画布 UITextLayoutCanvasView 找出来，把整块敏感 UI 挂进该画布；
///   - 系统安全管线在 截图 / 录屏 / App 切换缩略图 时清空该画布内容 → 变成黑色；
///   - 肉眼正常渲染、完全不激活键盘（canBecomeFirstResponder = false）。
///   若当前 iOS 找不到该私有画布，回退为直接把内容挂字段自身（UI 保持正常、不激活）。
final class SecureContainerView: UITextField {

    private weak var canvas: UIView?

    init() {
        super.init(frame: .zero)
        isSecureTextEntry = true
        borderStyle = .none
        backgroundColor = .clear
        text = ""
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 不激活键盘、不抢焦点、不弹输入提示条
    override var canBecomeFirstResponder: Bool { false }

    /// 完全穿透：不拦截任何触摸
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }

    /// 内容宿主：优先返回私有画布；取不到则回退字段自身
    func contentHost() -> UIView {
        if let c = canvas { return c }
        if let c = Self.locateCanvas(in: self) { canvas = c; return c }
        return self
    }

    private static func locateCanvas(in v: UIView) -> UIView? {
        if type(of: v).description() == "UITextLayoutCanvasView" { return v }
        for s in v.subviews {
            if let c = locateCanvas(in: s) { return c }
        }
        return nil
    }
}

/// 把任意根控制器（TabBar / 解锁页）的内容放进安全容器（私有画布）
final class SecureWrapperViewController: UIViewController {
    private let content: UIViewController
    private let secure: SecureContainerView
    private var fgObserver: NSObjectProtocol?
    private var hosted = false

    init(content: UIViewController) {
        self.content = content
        self.secure = SecureContainerView()
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let fgObserver { NotificationCenter.default.removeObserver(fgObserver) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let bg = UIColor(white: 0.06, alpha: 1)
        view.backgroundColor = bg

        // 底层：secure 字段（其私有画布承载内容）
        secure.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(secure)
        NSLayoutConstraint.activate([
            secure.topAnchor.constraint(equalTo: view.topAnchor),
            secure.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            secure.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            secure.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        addChild(content)
        content.view.backgroundColor = bg
        content.didMove(toParent: self)

        // 回前台后，把内容重新挂进（画布可能重建）
        fgObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.hostContent()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hostContent()
    }

    /// 把内容挂进 secure 字段的私有画布（hosted 保证只挂一次）
    private func hostContent() {
        guard !hosted else { return }
        hosted = true
        let host = secure.contentHost()
        let cv = content.view!
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.frame = host.bounds
        cv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.addSubview(cv)
    }

    override var shouldAutorotate: Bool { content.shouldAutorotate }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { content.supportedInterfaceOrientations }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
