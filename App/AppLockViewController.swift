import UIKit

/// 应用级解锁界面（启动 / 后台返回时）；支持主密码、胁迫密码、FaceID
final class AppLockViewController: UIViewController, UITextFieldDelegate {

    private var lockView: PasswordLockView!

    override func viewDidLoad() {
        super.viewDidLoad()
        GlassTheme.installScene(on: view)
        let showFace = LockManager.shared.useBiometrics && LockManager.canUseBiometrics()
        lockView = PasswordLockView(title: "隐私工具箱已锁定",
                                    submitTitle: "解锁",
                                    showFaceID: showFace)
        lockView.field.delegate = self
        lockView.field.returnKeyType = .go
        lockView.submit.addTarget(self, action: #selector(submit), for: .touchUpInside)
        if let face = lockView.viewWithTag(99) as? UIButton {
            face.addTarget(self, action: #selector(faceAuth), for: .touchUpInside)
        }
        view.addSubview(lockView)
        NSLayoutConstraint.activate([
            lockView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            lockView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lockView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            lockView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    func textFieldShouldReturn(_ f: UITextField) -> Bool { submit(); return true }

    @objc private func submit() {
        let r = LockManager.shared.verifyUnlock(lockView.field.text ?? "")
        switch r {
        case .ok: RootRouter.toMain()
        case .duress:
            // 胁迫密码：一键清空全部内容并闪退
            DataWiper.wipeAll()
        case .none: lockView.hint.text = "密码错误"
        }
        lockView.field.text = ""
    }

    @objc private func faceAuth() {
        LockManager.biometricPrompt(reason: "解锁隐私工具箱") { ok in
            if ok { RootRouter.toMain() }
        }
    }
}
