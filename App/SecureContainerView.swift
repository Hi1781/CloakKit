import UIKit

/// 安全渲染层：透明 UITextField（isSecureTextEntry），占满全屏。
///
/// 经验证（实机截图）：isSecureTextEntry 字段的安全文本 z 序永远在子视图之上，
/// 若把内容作为子视图挂进字段内，正常显示会被 ● 安全字形盖住（OCR 已确认遮挡文字）。
/// 因此改为「底层安全层」结构：
/// - SecureContainerView 作为 window 最底层的安全层（isSecureTextEntry + 不透明深色 ● 占满）；
/// - 真实内容作为**上层不透明层**盖住它 → 正常显示无 ● 露出；
/// - 截屏/录屏时，系统把 secure 字段文本区域黑化为色块 → 截图全黑（传纸条同款副作用）。
///
/// ⚠️ 诚实边界：此黑化是系统副作用，随 iOS 大版本可能失效；翻拍、越狱无法防范。
/// 配套防泄露：录屏检测全屏覆盖 + 截屏/录屏上报对端 + 通讯阅后即焚不落地。
final class SecureContainerView: UITextField {

    /// 不抢焦点，杜绝输入框被拦截
    override var canBecomeFirstResponder: Bool { false }

    init() {
        super.init(frame: .zero)
        isSecureTextEntry = true
        borderStyle = .none
        backgroundColor = .clear
        // 照搬传纸条：secure 安全层作为「最底层」，用不透明深色安全字形占满。
        // 正常：上层内容（透明背景）盖住 UI，安全字形在空白区以黑色显示（与黑背景融合，不可见）；
        // 截屏/录屏：系统把 secure 字段的文本区域黑化为色块（最顶层）→ 全屏黑。
        textColor = UIColor(white: 0.06, alpha: 1)
        font = UIFont.systemFont(ofSize: 320)
        text = String(repeating: "●", count: 200)
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 安全层完全不参与触摸：一律穿透到下层内容，绝不拦截任何点击。
    /// 否则安全层内部的文本子视图会吃掉触摸，导致语音/照片/文件等无法交互。
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

        // 底层：secure 安全层（isSecureTextEntry + 不透明深色安全字形占满）。
        // 截屏/录屏时系统黑化其文本区域 → 全屏黑。
        let s = SecureContainerView()
        s.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(s)
        NSLayoutConstraint.activate([
            s.topAnchor.constraint(equalTo: view.topAnchor),
            s.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            s.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            s.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // 上层：真实内容，透明背景 → UI 元素盖在安全字形之上正常显示，
        // 安全字形在空白区以黑色显示（与黑背景融合不可见），且 secure 始终可见 → 触发截图黑化。
        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        content.view.backgroundColor = .clear
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
