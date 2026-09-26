import UIKit

/// 模块级锁容器：浏览器 / 传话 / 互传 等敏感板块，密码页与逻辑照搬私密相册页。
/// - 首次进入且未设密码 → 相册式「首次设置」（主密码 + 诱饵密码）
/// - 已设密码 → 相册式「解锁」（主密码→真实内容；诱饵密码→空壳页面，不显示任何标识）
/// - 支持 FaceID / 指纹
final class FeatureLockController: UIViewController {

    private let childVC: UIViewController
    private let moduleKey: String
    private let featureName: String
    private var lockView: ModuleVaultLockView?
    private var childShown = false
    private var decoyShown = false

    init(child: UIViewController, moduleKey: String, featureName: String) {
        self.childVC = child
        self.moduleKey = moduleKey
        self.featureName = featureName
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        GlassTheme.installScene(on: view)
        let lm = LockManager.shared
        if !lm.hasModulePassword(moduleKey) {
            showSetupLock()          // 首次：相册式设置（主+诱饵）
        } else if lm.isModuleUnlocked(moduleKey) {
            presentChild()
        } else {
            showUnlockLock()          // 相册式解锁
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 从其他页切回：若已锁定则确保回到锁屏
        let lm = LockManager.shared
        if !lm.isModuleUnlocked(moduleKey) && (childShown || decoyShown) {
            lockNow()
        }
    }

    /// 切走其他页面时调用：立即锁定本板块（幂等）
    func lockNow() {
        let lm = LockManager.shared
        if lm.isModuleUnlocked(moduleKey) { lm.lockModule(moduleKey) }
        removeChild()
        decoyShown = false
        if isViewLoaded && lockView == nil {
            if lm.hasModulePassword(moduleKey) { showUnlockLock() } else { showSetupLock() }
        }
    }

    private func removeChild() {
        childVC.willMove(toParent: nil)
        childVC.view.removeFromSuperview()
        childVC.removeFromParent()
        childShown = false
    }

    // MARK: - 首次设置（照搬相册 showSetup）
    private func showSetupLock() {
        let v = ModuleVaultLockView(featureName: featureName, isSetup: true, showFaceID: false)
        v.onSetup = { [weak self] master, decoy in
            guard let self = self else { return }
            let lm = LockManager.shared
            lm.setModulePassword(self.moduleKey, master)
            lm.setModuleDecoy(self.moduleKey, decoy)
            lm.unlockModule(self.moduleKey)
            self.tearDownLock()
            self.presentChild()
        }
        install(v)
    }

    // MARK: - 解锁（照搬相册 showLock）
    private func showUnlockLock() {
        let lm = LockManager.shared
        let v = ModuleVaultLockView(featureName: featureName, isSetup: false,
                                    showFaceID: lm.useBiometrics && LockManager.canUseBiometrics())
        v.onUnlock = { [weak self] result, pwd in
            guard let self = self else { return }
            switch result {
            case .real: self.presentChild()
            case .decoy: self.presentDecoy()
            case .none: self.unlockTry(pwd)
            }
        }
        install(v)
    }

    private func unlockTry(_ pwd: String) {
        guard let v = lockView else { return }
        let lm = LockManager.shared
        if lm.verifyModulePassword(moduleKey, pwd) {
            lm.unlockModule(moduleKey)
            tearDownLock()
            presentChild()
        } else if lm.verifyModuleDecoy(moduleKey, pwd) {
            tearDownLock()
            presentDecoy()
        } else {
            v.setHint("密码错误")
        }
    }

    private func install(_ v: ModuleVaultLockView) {
        lockView = v
        view.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            v.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            v.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func tearDownLock() {
        lockView?.removeFromSuperview()
        lockView = nil
    }

    // MARK: - 内容
    private func presentChild() {
        childShown = true
        decoyShown = false
        addChild(childVC)
        childVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(childVC.view)
        NSLayoutConstraint.activate([
            childVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            childVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            childVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        childVC.didMove(toParent: self)
        navigationItem.title = featureName
        navigationItem.rightBarButtonItems = childVC.navigationItem.rightBarButtonItems
    }

    /// 诱饵密码进入的空壳：显示一个看起来正常但内容为空的页面（不出现任何诱饵标识）
    private func presentDecoy() {
        decoyShown = true
        childShown = false
        navigationItem.title = featureName
        navigationItem.rightBarButtonItems = nil

        let empty = UIView()
        empty.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(empty)
        NSLayoutConstraint.activate([
            empty.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            empty.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            empty.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            empty.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
