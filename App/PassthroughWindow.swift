import UIKit

// MARK: - 顶层透传窗口（照搬传纸条 PassthroughWindow）
// 以高于主窗口的 windowLevel 常驻顶层；hitTest 返回 nil → 透传触摸，不打断操作。
// 承载"监测到正在录屏"警示层（白底 + 绿色护盾 + 黑字），录屏/镜像时盖住全屏。
final class PassthroughWindow: UIWindow {

    private let coverView: UIView
    private let shield: UIImageView
    private let label: UILabel

    override init(windowScene: UIWindowScene) {
        coverView = UIView()
        shield = UIImageView(image: UIImage(systemName: "checkmark.shield.fill"))
        label = UILabel()
        super.init(windowScene: windowScene)
        backgroundColor = .clear
        rootViewController = UIViewController()
        windowLevel = UIWindow.Level.alert + 1
        isHidden = true

        coverView.backgroundColor = .white
        coverView.translatesAutoresizingMaskIntoConstraints = false
        shield.tintColor = .systemGreen
        shield.contentMode = .scaleAspectFit
        label.text = "监测到正在录屏"
        label.textColor = .black
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [shield, label])
        stack.axis = .vertical
        stack.spacing = 18
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        coverView.addSubview(stack)

        guard let root = rootViewController?.view else { return }
        root.addSubview(coverView)
        NSLayoutConstraint.activate([
            coverView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            coverView.topAnchor.constraint(equalTo: root.topAnchor),
            coverView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            shield.widthAnchor.constraint(equalToConstant: 96),
            shield.heightAnchor.constraint(equalToConstant: 96),
            stack.centerXAnchor.constraint(equalTo: coverView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: coverView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 透传触摸：返回 nil，事件落到下层窗口
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }

    func showCover() { isHidden = false }
    func hideCover() { isHidden = true }
}
