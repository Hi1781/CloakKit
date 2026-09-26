import UIKit

/// 模块级锁容器：浏览器 / 传话 / 互传 等敏感板块包一层，验证主密码后才显示内容
final class FeatureLockController: UIViewController, UITextFieldDelegate {

    private let childVC: UIViewController
    private let moduleKey: String
    private let featureName: String
    private var lockView: PasswordLockView?
    private var childShown = false

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
        if LockManager.shared.isModuleUnlocked(moduleKey) {
            presentChild()
        } else {
            showLock()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 从其他页切回：若已锁定则确保回到锁屏
        if !LockManager.shared.isModuleUnlocked(moduleKey) && childShown {
            lockNow()
        }
    }

    /// 切走其他页面时调用：立即锁定本板块（幂等）
    func lockNow() {
        if LockManager.shared.isModuleUnlocked(moduleKey) {
            LockManager.shared.lockModule(moduleKey)
        }
        if childShown { removeChild() }
        if lockView == nil { showLock() }
    }

    private func removeChild() {
        childVC.willMove(toParent: nil)
        childVC.view.removeFromSuperview()
        childVC.removeFromParent()
        childShown = false
    }

    private func showLock() {
        let useSecondary = LockManager.shared.hasSecondary
        lockView = PasswordLockView(title: "\(featureName)已锁定",
                                    submitTitle: "解锁",
                                    showFaceID: LockManager.shared.useBiometrics && LockManager.canUseBiometrics(),
                                    subtitle: useSecondary ? "输入二级密码以访问此板块" : "输入应用密码以访问此板块")
        lockView!.field.delegate = self
        lockView!.field.returnKeyType = .go
        lockView!.submit.addTarget(self, action: #selector(submit), for: .touchUpInside)
        if let face = lockView!.viewWithTag(99) as? UIButton {
            face.addTarget(self, action: #selector(faceAuth), for: .touchUpInside)
        }
        view.addSubview(lockView!)
        NSLayoutConstraint.activate([
            lockView!.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            lockView!.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lockView!.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            lockView!.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func presentChild() {
        childShown = true
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
        // 让子控制器能正常压栈导航
        navigationItem.title = featureName
        navigationItem.rightBarButtonItems = childVC.navigationItem.rightBarButtonItems
    }

    func textFieldShouldReturn(_ f: UITextField) -> Bool { submit(); return true }

    @objc private func submit() {
        let pwd = lockView?.field.text ?? ""
        let ok = LockManager.shared.hasSecondary
            ? LockManager.shared.verifySecondary(pwd)
            : LockManager.shared.verifyMaster(pwd)
        if ok {
            LockManager.shared.unlockModule(moduleKey)
            lockView?.removeFromSuperview()
            presentChild()
        } else {
            lockView?.hint.text = "密码错误"
        }
        lockView?.field.text = ""
    }

    @objc private func faceAuth() {
        LockManager.biometricPrompt(reason: "解锁\(featureName)") { [weak self] ok in
            guard let self = self, ok else { return }
            LockManager.shared.unlockModule(self.moduleKey)
            self.lockView?.removeFromSuperview()
            self.presentChild()
        }
    }
}
