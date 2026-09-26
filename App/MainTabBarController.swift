import UIKit

/// 隐私工具箱 · 根 TabBar（8 大模块；浏览器/传话/互传为锁包模块，相册自带锁）
/// 切到其他 Tab 时，自动锁定刚离开的敏感板块
final class MainTabBarController: UITabBarController, UITabBarControllerDelegate {

    private var lastIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        let tabs: [(String, String, UIViewController)] = [
            ("设备", "info.circle", DeviceInfoViewController()),
            ("监控", "waveform.path.ecg", PerformanceViewController()),
            ("审计", "doc.text.magnifyingglass", PrivacyLogViewController()),
            ("相册", "lock.shield", VaultViewController()),
            ("浏览器", "globe",
             FeatureLockController(child: PrivacyBrowserViewController(), moduleKey: "browser", featureName: "隐私浏览器")),
            ("传话", "bubble.left.and.bubble.right",
             FeatureLockController(child: MessagingViewController(), moduleKey: "chat", featureName: "私密通讯")),
            ("互传", "arrow.left.arrow.right",
             FeatureLockController(child: FileTransferViewController(), moduleKey: "transfer", featureName: "文件互传")),
            ("设置", "gearshape", SettingsViewController()),
        ]
        let vcs = tabs.map { (title, symbol, vc) -> UINavigationController in
            let nav = UINavigationController(rootViewController: vc)
            nav.tabBarItem = UITabBarItem(title: title,
                                          image: UIImage(systemName: symbol),
                                          selectedImage: UIImage(systemName: symbol))
            return nav
        }
        viewControllers = vcs
        tabBar.isTranslucent = true
        view.backgroundColor = .clear
        GlassTheme.installScene(on: view)
    }

    // MARK: - 切走即锁定上一页
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard let vcs = viewControllers, lastIndex < vcs.count, lastIndex != selectedIndex else {
            lastIndex = selectedIndex
            return
        }
        let prevNav = vcs[lastIndex] as? UINavigationController
        // 浏览器 / 传话 / 互传 用 FeatureLockController
        if lastIndex == 4 || lastIndex == 5 || lastIndex == 6 {
            if let flc = prevNav?.viewControllers.first as? FeatureLockController {
                flc.lockNow()
            }
        }
        // 相册自带锁
        if lastIndex == 3 {
            if let v = prevNav?.viewControllers.first as? VaultViewController {
                v.reLock()
            }
        }
        lastIndex = selectedIndex
    }
}
