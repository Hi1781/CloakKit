import UIKit

/// 全局防护：录屏检测覆盖 + 截屏告警
/// （截屏黑化由根路由的 SecureWrapperViewController 安全容器承担，此处只做录屏覆盖与截屏提示）
final class ScreenGuard {
    private static weak var window: UIWindow?
    private static var overlay: UIView?
    private static var toast: UILabel?
    private static var observers: [NSObjectProtocol] = []

    static func install(on w: UIWindow) {
        window = w

        // 1) 录屏检测覆盖层
        buildOverlay(w)

        // 2) 录屏变化监听（检测到即全屏覆盖 + 上报对端）
        let capObs = NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main
        ) { _ in
            updateRecording()
            if UIScreen.main.isCaptured {
                ChatStore.shared.addThreatAlert("对方设备正在录屏/投屏，已自动上报安全告警")
            }
        }
        observers.append(capObs)
        updateRecording()

        // 3) 截屏提示（截图完成后触发，无法阻止截图生成，仅告警 + 上报对端）
        let shotObs = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main
        ) { _ in
            ChatStore.shared.addThreatAlert("对方设备已截屏，已自动上报安全告警")
            showToast("已检测到截屏 · 已上报对方")
        }
        observers.append(shotObs)
    }

    private static func buildOverlay(_ w: UIWindow) {
        let o = UIView()
        o.backgroundColor = .white

        let shield = UIImageView(image: UIImage(systemName: "checkmark.shield.fill"))
        shield.tintColor = .systemGreen
        shield.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = "监测到正在录屏"
        label.textColor = .black
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [shield, label])
        stack.axis = .vertical
        stack.spacing = 18
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        o.addSubview(stack)
        NSLayoutConstraint.activate([
            shield.widthAnchor.constraint(equalToConstant: 96),
            shield.heightAnchor.constraint(equalToConstant: 96),
            stack.centerXAnchor.constraint(equalTo: o.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: o.centerYAnchor),
        ])

        o.isHidden = true
        o.translatesAutoresizingMaskIntoConstraints = false
        w.addSubview(o)
        NSLayoutConstraint.activate([
            o.topAnchor.constraint(equalTo: w.topAnchor),
            o.bottomAnchor.constraint(equalTo: w.bottomAnchor),
            o.leadingAnchor.constraint(equalTo: w.leadingAnchor),
            o.trailingAnchor.constraint(equalTo: w.trailingAnchor),
        ])
        overlay = o
    }

    private static func updateRecording() {
        if let o = overlay, let w = window {
            w.bringSubviewToFront(o)
            o.isHidden = !UIScreen.main.isCaptured
        }
    }

    private static func showToast(_ text: String) {
        guard let w = window else { return }
        if let t = toast { t.removeFromSuperview(); toast = nil }
        let t = UILabel()
        t.text = text
        t.textColor = .white
        t.font = .systemFont(ofSize: 14, weight: .semibold)
        t.textAlignment = .center
        t.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        t.layer.cornerRadius = 8
        t.clipsToBounds = true
        t.translatesAutoresizingMaskIntoConstraints = false
        w.addSubview(t)
        NSLayoutConstraint.activate([
            t.centerXAnchor.constraint(equalTo: w.centerXAnchor),
            t.centerYAnchor.constraint(equalTo: w.centerYAnchor, constant: -120),
            t.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            t.heightAnchor.constraint(equalToConstant: 44),
        ])
        toast = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UIView.animate(withDuration: 0.25, animations: { t.alpha = 0 }) { _ in
                t.removeFromSuperview()
                if toast === t { toast = nil }
            }
        }
    }
}
