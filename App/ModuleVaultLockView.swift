import UIKit

/// 相册式模块锁视图：UI 与私密相册完全一致（玻璃卡片 + lock 图标 + 密码框 + FaceID）。
/// 两种模式：
/// - 首次设置：主密码 + 诱饵密码（照搬相册 showSetup）
/// - 解锁：单密码框，主密码→真实内容、诱饵密码→空壳（照搬相册 showLock）
final class ModuleVaultLockView: UIView, UITextFieldDelegate {

    enum Unlock { case real, decoy, none }
    var onSetup: ((String, String) -> Void)?   // (主密码, 诱饵密码)
    var onUnlock: ((Unlock, String) -> Void)?  // (结果, 输入的密码)

    private let featureName: String
    private let isSetupMode: Bool
    private let masterField = UITextField()
    private let decoyField = UITextField()
    private let hint = UILabel()

    init(featureName: String, isSetup: Bool, showFaceID: Bool) {
        self.featureName = featureName
        self.isSetupMode = isSetup
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        if isSetup { buildSetup() } else { buildLock(showFaceID: showFaceID) }
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 样式工具（与相册一致）
    private func styleField(_ f: UITextField, placeholder: String) {
        f.placeholder = placeholder
        f.isSecureTextEntry = true
        f.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        f.layer.borderWidth = 0.5
        f.layer.borderColor = GlassTheme.stroke.cgColor
        f.textColor = .white
        f.layer.cornerRadius = 8
        f.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 40))
        f.leftViewMode = .always
    }

    // MARK: - 首次设置（照搬相册 showSetup）
    private func buildSetup() {
        let t = UILabel()
        t.text = "首次使用：设置「\(featureName)」密码"
        t.textColor = .white
        t.font = .systemFont(ofSize: 20, weight: .semibold)
        t.numberOfLines = 0
        let note = UILabel()
        note.text = "设置板块主密码，可另设诱饵密码。输入诱饵密码时进入空壳页面。"
        note.textColor = .systemGray2
        note.font = .systemFont(ofSize: 13)
        note.numberOfLines = 0

        styleField(masterField, placeholder: "主密码（≥4位）")
        styleField(decoyField, placeholder: "诱饵密码（≥4位）")
        decoyField.delegate = self

        let done = UIButton(type: .system)
        done.setTitle("创建", for: .normal)
        done.backgroundColor = .systemBlue
        done.setTitleColor(.white, for: .normal)
        done.layer.cornerRadius = 8
        done.addTarget(self, action: #selector(setupDone), for: .touchUpInside)

        let v = UIStackView(arrangedSubviews: [t, note, masterField, decoyField, done])
        v.axis = .vertical
        v.spacing = 14
        v.translatesAutoresizingMaskIntoConstraints = false
        addSubview(v)
        NSLayoutConstraint.activate([
            v.centerYAnchor.constraint(equalTo: centerYAnchor),
            v.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            v.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            masterField.heightAnchor.constraint(equalToConstant: 44),
            decoyField.heightAnchor.constraint(equalToConstant: 44),
            done.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    @objc private func setupDone() {
        let p = masterField.text ?? ""
        let d = decoyField.text ?? ""
        guard p.count >= 4, d.count >= 4 else {
            hint(text: "主密码与诱饵密码均需 ≥4 位")
            return
        }
        onSetup?(p, d)
    }

    // MARK: - 解锁（照搬相册 showLock）
    private func buildLock(showFaceID: Bool) {
        let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit

        let t = UILabel()
        t.text = "\(featureName)已锁定"
        t.textColor = .white
        t.font = .systemFont(ofSize: 20, weight: .semibold)
        t.textAlignment = .center

        styleField(masterField, placeholder: "输入密码")
        masterField.returnKeyType = .go
        masterField.delegate = self

        let unlockBtn = UIButton(type: .system)
        unlockBtn.setTitle("解锁", for: .normal)
        unlockBtn.backgroundColor = .systemBlue
        unlockBtn.setTitleColor(.white, for: .normal)
        unlockBtn.layer.cornerRadius = 8
        unlockBtn.addTarget(self, action: #selector(doUnlock), for: .touchUpInside)

        hint.text = " "
        hint.textColor = .systemGray2
        hint.font = .systemFont(ofSize: 12)

        let arranged: [UIView] = [icon, t, masterField, unlockBtn, hint]
        let v = UIStackView(arrangedSubviews: arranged)
        v.axis = .vertical
        v.spacing = 14
        let card = GlassTheme.glassCard(content: v, radius: 24)
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.widthAnchor.constraint(equalToConstant: 300),
            icon.heightAnchor.constraint(equalToConstant: 64),
            masterField.heightAnchor.constraint(equalToConstant: 44),
            unlockBtn.heightAnchor.constraint(equalToConstant: 44),
        ])

        if showFaceID {
            let f = UIButton(type: .system)
            f.setImage(UIImage(systemName: "faceid"), for: .normal)
            f.tintColor = .systemBlue
            f.setTitle("  使用 FaceID / 指纹", for: .normal)
            f.addTarget(self, action: #selector(faceAuth), for: .touchUpInside)
            v.insertArrangedSubview(f, at: 3)
        }
    }

    @objc private func doUnlock() {
        let p = masterField.text ?? ""
        guard p.count >= 4 else { hint(text: "密码至少 4 位"); masterField.text = ""; return }
        onUnlock?(.none, p)
    }

    /// 控制器判定后设置提示
    func setHint(_ s: String, red: Bool = true) {
        hint.text = s
        hint.textColor = red ? .systemRed : .systemGray2
        masterField.text = ""
    }

    func hint(text: String) {
        hint.text = text
        hint.textColor = .systemRed
    }

    @objc private func faceAuth() {
        LockManager.biometricPrompt(reason: "解锁\(featureName)") { [weak self] ok in
            if ok { self?.onUnlock?(.real, "") }
        }
    }

    func textFieldShouldReturn(_ f: UITextField) -> Bool {
        if isSetupMode { setupDone() } else { doUnlock() }
        return true
    }
}
