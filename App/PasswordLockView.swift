import UIKit

/// 通用密码锁界面（设置密码 / 解锁 / 模块锁共用）
final class PasswordLockView: UIView {
    let field = UITextField()
    let hint = UILabel()
    let submit = UIButton(type: .system)

    init(title: String, submitTitle: String, showFaceID: Bool, subtitle: String? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        icon.tintColor = GlassTheme.tint
        icon.contentMode = .scaleAspectFit

        let t = UILabel()
        t.text = title
        t.textColor = .white
        t.font = .systemFont(ofSize: 22, weight: .semibold)
        t.textAlignment = .center

        var arranged: [UIView] = [icon, t]

        if let sub = subtitle {
            let s = UILabel()
            s.text = sub
            s.textColor = .systemGray2
            s.font = .systemFont(ofSize: 13)
            s.textAlignment = .center
            s.numberOfLines = 0
            arranged.append(s)
        }

        field.placeholder = "输入密码"
        field.isSecureTextEntry = true
        field.backgroundColor = UIColor(white: 0.14, alpha: 1)
        field.textColor = .white
        field.layer.cornerRadius = 8
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 44))
        field.leftViewMode = .always
        field.returnKeyType = .go

        hint.text = " "
        hint.textColor = .systemRed
        hint.font = .systemFont(ofSize: 13)
        hint.textAlignment = .center

        submit.setTitle(submitTitle, for: .normal)
        submit.backgroundColor = GlassTheme.tint
        submit.setTitleColor(.white, for: .normal)
        submit.layer.cornerRadius = 8

        arranged.append(contentsOf: [field, submit, hint])

        let stack = UIStackView(arrangedSubviews: arranged)
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.widthAnchor.constraint(equalToConstant: 260),
            icon.heightAnchor.constraint(equalToConstant: 60),
            field.heightAnchor.constraint(equalToConstant: 44),
            submit.heightAnchor.constraint(equalToConstant: 44),
        ])

        if showFaceID {
            let f = UIButton(type: .system)
            f.setImage(UIImage(systemName: "faceid"), for: .normal)
            f.tintColor = GlassTheme.tint
            f.setTitle("  使用 FaceID / 指纹", for: .normal)
            f.tag = 99
            stack.insertArrangedSubview(f, at: arranged.count - 1)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
}
