import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var blurView: UIVisualEffectView?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        GlassTheme.configureAppearance()
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = UIColor(white: 0.06, alpha: 1)
        RootRouter.window = window
        RootRouter.resolve(in: window)
        window.makeKeyAndVisible()
        self.window = window

        // 全局防截屏 / 防录屏
        ScreenGuard.install(on: window)

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(didResign),
                       name: UIApplication.willResignActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(didEnterBG),
                       name: UIApplication.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(didBecomeActive),
                       name: UIApplication.didBecomeActiveNotification, object: nil)

        // 从「打开方式 / 分享」接收 .json 隐私报告
        if let url = connectionOptions.urlContexts.first?.url {
            _ = PrivacyReportStore.shared.importFile(url: url)
        }
    }

    // MARK: - 后台模糊 + 返回重锁
    @objc private func didResign() {
        if LockManager.shared.hasAppLock && LockManager.shared.autoLockOnBackground {
            LockManager.shared.appUnlocked = false
        }
        addBlur()
    }
    @objc private func didEnterBG() { addBlur() }
    @objc private func didBecomeActive() {
        removeBlur()
        if LockManager.shared.hasAppLock, !LockManager.shared.appUnlocked,
           let w = window {
            RootRouter.resolve(in: w)
        }
    }

    private func addBlur() {
        guard blurView == nil, let window = window else { return }
        let b = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        b.frame = window.bounds
        b.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(b)
        blurView = b
    }
    private func removeBlur() {
        blurView?.removeFromSuperview()
        blurView = nil
    }

    // 「打开方式」接收文件
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for ctx in URLContexts {
            _ = PrivacyReportStore.shared.importFile(url: ctx.url)
        }
    }
}
