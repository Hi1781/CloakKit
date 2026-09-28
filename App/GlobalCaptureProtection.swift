import Foundation

// MARK: - 全局防截屏/防录屏开关（照搬传纸条 GlobalCaptureProtection）
final class GlobalCaptureProtection {
    static let shared = GlobalCaptureProtection()

    /// 是否启用防截屏/防录屏保护。默认开启。
    var isEnabled: Bool = true {
        didSet {
            NotificationCenter.default.post(name: .globalCaptureProtectionDidChange, object: self)
        }
    }
    private init() {}
}

extension Notification.Name {
    static let globalCaptureProtectionDidChange = Notification.Name("globalCaptureProtectionDidChange")
}
