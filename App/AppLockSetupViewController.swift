import UIKit

/// 首次使用：设置应用主密码（同时用于后四板块锁）
final class AppLockSetupViewController: UIViewController, UITextFieldDelegate {

    private let field = UITextField()
    private let confirm = UITextField()
    private let hint = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        GlassTheme.installScene(on: view)

        let title = UILabel()
        title.text = "设置应用密码"
        title.textColor = .white
        title.font = .systemFont(ofSize: 22, weight: .semibold)

        let sub = UILabel()
        sub.text = "该密码用于解锁应用整体及隐私浏览器、私密通讯、文件互传等敏感板块。"
        sub.textColor = .systemGray2
        sub.font = .systemFont(ofSize: 13)
        sub.numberOfLines = 0

        field.placeholder = "应用密码（≥4位）"
        field.isSecureTextEntry = true
        field.backgroundColor = UIColor(white: 0.14, alpha: 1)
        field.textColor = .white
        field.layer.cornerRadius = 8
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 44))
        field.leftViewMode = .always
        field.returnKeyType = .next

        confirm.placeholder = "确认密码"
        confirm.isSecureTextEntry = true
        confirm.backgroundColor = UIColor(white: 0.14, alpha: 1)
        confirm.textColor = .white
        confirm.layer.cornerRadius = 8
        confirm.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 44))
        confirm.leftViewMode = .always
        confirm.returnKeyType = .done
        confirm.delegate = self

        hint.textColor = .systemRed
        hint.font = .systemFont(ofSize: 13)
        hint.textAlignment = .center

        let done = UIButton(type: .system)
        done.setTitle("设置并进入", for: .normal)
        done.backgroundColor = GlassTheme.tint
        done.setTitleColor(.white, for: .normal)
        done.layer.cornerRadius = 8
        done.addTarget(self, action: #selector(submit), for: .touchUpInside)

        let v = UIStackView(arrangedSubviews: [title, sub, field, confirm, done, hint])
        v.axis = .vertical
        v.spacing = 14
        v.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(v)
        NSLayoutConstraint.activate([
            v.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            v.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            v.widthAnchor.constraint(equalToConstant: 280),
            field.heightAnchor.constraint(equalToConstant: 44),
            confirm.heightAnchor.constraint(equalToConstant: 44),
            done.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    func textFieldShouldReturn(_ f: UITextField) -> Bool {
        if f === field { confirm.becomeFirstResponder() }
        else { submit() }
        return true
    }

    @objc private func submit() {
        let p = field.text ?? ""
        let c = confirm.text ?? ""
        guard p.count >= 4 else { hint.text = "密码至少 4 位"; return }
        guard p == c else { hint.text = "两次输入不一致"; return }
        LockManager.shared.setupMasterPassword(p)
        RootRouter.toMain()
    }
}
