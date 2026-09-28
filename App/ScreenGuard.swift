import UIKit

/// 全局防护（照搬传纸条机制 + 保留截屏告警）
/// 录屏/镜像 → 顶层透传窗口承载"监测到正在录屏"全屏警示（GlobalCaptureProtection 开关控制）
/// 截屏 → 检测后上报对端 + 本地提示（无法阻止截图生成，仅告警/威慑/溯源）
final class ScreenGuard {
    private static var shield: PassthroughWindow?
    private static var toast: UILabel?
    private static var observers: [NSObjectProtocol] = []

    static func install(on w: UIWindow) {
        guard let ws = w.windowScene else { return }

        // 顶层透传窗口（承载录屏警示层），常驻、透传触摸
        let s = PassthroughWindow(windowScene: ws)
        s.showCover() // 先挂载；由状态刷新决定显隐
        shield = s

        // 1) 录屏状态变化 → 刷新遮挡
        let capObs = NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main
        ) { _ in
            refreshShield()
            if UIScreen.main.isCaptured {
                ChatStore.shared.addThreatAlert("对方设备正在录屏/投屏，已自动上报安全告警")
            }
        }
        observers.append(capObs)

        // 2) 全局开关变化 → 刷新遮挡
        let togObs = NotificationCenter.default.addObserver(
            forName: .globalCaptureProtectionDidChange, object: nil, queue: .main
        ) { _ in
            refreshShield()
        }
        observers.append(togObs)

        // 3) 截屏提示（截图完成后触发，无法阻止，仅告警 + 上报对端）
        let shotObs = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main
        ) { _ in
            ChatStore.shared.addThreatAlert("对方设备已截屏，已自动上报安全告警")
            showToast("已检测到截屏 · 已上报对方")
        }
        observers.append(shotObs)

        refreshShield()
    }

    /// 全局开关（设置页可关）
    static var isEnabled: Bool {
        get { GlobalCaptureProtection.shared.isEnabled }
        set { GlobalCaptureProtection.shared.isEnabled = newValue }
    }

    private static func refreshShield() {
        guard let s = shield else { return }
        if UIScreen.main.isCaptured && GlobalCaptureProtection.shared.isEnabled {
            s.showCover()
        } else {
            s.hideCover()
        }
    }

    private static func showToast(_ text: String) {
        guard let ws = shield?.windowScene else { return }
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
        let host = UIWindow(windowScene: ws)
        host.windowLevel = .alert + 2
        host.rootViewController = UIViewController()
        host.isHidden = false
        host.addSubview(t)
        NSLayoutConstraint.activate([
            t.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            t.centerYAnchor.constraint(equalTo: host.centerYAnchor, constant: -120),
            t.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            t.heightAnchor.constraint(equalToConstant: 44),
        ])
        toast = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UIView.animate(withDuration: 0.25, animations: { t.alpha = 0 }) { _ in
                t.removeFromSuperview()
                host.isHidden = true
                if toast === t { toast = nil }
            }
        }
    }
}
