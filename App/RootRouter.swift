import UIKit

/// 根控制器路由：引导 → 设密 → 解锁 → 主界面
enum RootRouter {
    static weak var window: UIWindow?

    static func resolve(in w: UIWindow) {
        window = w
        let defs = UserDefaults.standard
        let root: UIViewController
        if !defs.bool(forKey: "onboarded_v2") {
            root = OnboardingViewController()
        } else if !LockManager.shared.hasAppLock {
            root = AppLockSetupViewController()
        } else if !LockManager.shared.appUnlocked {
            root = AppLockViewController()
        } else {
            root = MainTabBarController()
        }
        transition(to: root, in: w)
    }

    static func toMain() {
        guard let w = window else { return }
        LockManager.shared.appUnlocked = true
        LockManager.shared.decoyActive = false
        transition(to: MainTabBarController(), in: w)
    }

    static func toSetup() {
        guard let w = window else { return }
        transition(to: AppLockSetupViewController(), in: w)
    }

    static func transition(to vc: UIViewController, in w: UIWindow) {
        // 统一包进安全容器：让整页内容在系统截屏/录屏缓冲区渲染为黑
        w.rootViewController = SecureWrapperViewController(content: vc)
        UIView.transition(with: w, duration: 0.35,
                          options: [.transitionCrossDissolve], animations: nil)
    }
}
