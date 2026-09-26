import UIKit

/// 设置页：修改主密码、二级密码、胁迫密码、FaceID/指纹、后台自动锁定、关于
final class SettingsViewController: UITableViewController {

    private enum Section: Int, CaseIterable {
        case security, modules, about
    }
    private let lm = LockManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        GlassTheme.installScene(on: view)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    // MARK: - 数据源
    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .security: return "应用安全"
        case .modules: return "各板块独立密码"
        default: return "关于"
        }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .security: return 5
        case .modules: return 3
        default: return 3
        }
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .value1, reuseIdentifier: "cell")
        c.textLabel?.textColor = .white
        c.detailTextLabel?.textColor = .systemGray2
        GlassTheme.glassCell(on: c)
        c.accessoryView = nil
        if Section(rawValue: indexPath.section) == .security {
            switch indexPath.row {
            case 0:
                c.textLabel?.text = "修改主密码"
                c.accessoryType = .disclosureIndicator
            case 1:
                c.textLabel?.text = "二级密码（模块锁）"
                c.detailTextLabel?.text = lm.hasSecondary ? "已设置" : "未设置"
                c.accessoryType = .disclosureIndicator
            case 2:
                c.textLabel?.text = "胁迫密码"
                c.detailTextLabel?.text = lm.hasDuress ? "已设置" : "未设置"
                c.accessoryType = .disclosureIndicator
            case 3:
                c.textLabel?.text = "Face ID / 指纹"
                let sw = UISwitch()
                sw.isOn = lm.useBiometrics
                sw.isEnabled = LockManager.canUseBiometrics()
                sw.addTarget(self, action: #selector(bioToggle(_:)), for: .valueChanged)
                c.accessoryView = sw
            default:
                c.textLabel?.text = "后台自动锁定"
                let sw = UISwitch()
                sw.isOn = lm.autoLockOnBackground
                sw.addTarget(self, action: #selector(lockToggle(_:)), for: .valueChanged)
                c.accessoryView = sw
            }
        } else if Section(rawValue: indexPath.section) == .modules {
            let (name, key) = moduleInfo(indexPath.row)
            c.textLabel?.text = name + "（独立密码）"
            c.detailTextLabel?.text = lm.hasModulePassword(key) ? "已设置" : "使用主密码"
            c.accessoryType = .disclosureIndicator
        } else {
            switch indexPath.row {
            case 0:
                c.textLabel?.text = "版本"
                let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.3.0"
                c.detailTextLabel?.text = "v\(v)"
            case 1:
                c.textLabel?.text = "免责声明"
                c.accessoryType = .disclosureIndicator
            default:
                c.textLabel?.text = "隐私说明"
                c.accessoryType = .disclosureIndicator
            }
        }
        return c
    }

    private func moduleInfo(_ row: Int) -> (String, String) {
        switch row {
        case 0: return ("浏览器", "browser")
        case 1: return ("传话", "chat")
        default: return ("互传", "transfer")
        }
    }

    @objc private func bioToggle(_ s: UISwitch) { lm.useBiometrics = s.isOn }
    @objc private func lockToggle(_ s: UISwitch) { lm.autoLockOnBackground = s.isOn }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .security else {
            if indexPath.row == 1 {
                let dis = DisclaimerViewController()
                dis.modalPresentationStyle = .pageSheet
                present(dis, animated: true)
            } else if indexPath.row == 2 {
                let a = UIAlertController(title: "隐私说明", message: "所有数据仅存本机沙盒，不上传任何服务器。通讯/互传采用端到端机制。", preferredStyle: .alert)
                a.addAction(UIAlertAction(title: "好", style: .default))
                present(a, animated: true)
            }
            return
        }
        if Section(rawValue: indexPath.section) == .modules {
            let (name, key) = moduleInfo(indexPath.row)
            editModulePassword(key: key, name: name)
            return
        }
        switch indexPath.row {
        case 0: changePassword()
        case 1: editSecondary()
        case 2: editDuress()
        default: break
        }
    }

    // MARK: - 每模块独立密码
    private func editModulePassword(key: String, name: String) {
        let a = UIAlertController(title: "「\(name)」独立密码",
                                  message: "设置后，打开该板块需输入独立密码；留空则清除（回退主密码）。", preferredStyle: .alert)
        a.addTextField { $0.isSecureTextEntry = true; $0.placeholder = "独立密码（≥4位，留空清除）" }
        a.addTextField { $0.isSecureTextEntry = true; $0.placeholder = "确认" }
        a.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let p = a.textFields![0].text ?? ""
            let c = a.textFields![1].text ?? ""
            if p.isEmpty { self.lm.setModulePassword(key, nil); self.alert("已清除「\(name)」独立密码"); return }
            guard p.count >= 4 else { self.alert("至少 4 位"); return }
            guard p == c else { self.alert("两次不一致"); return }
            self.lm.setModulePassword(key, p)
            self.alert("「\(name)」独立密码已设置")
        })
        a.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(a, animated: true)
    }

    // MARK: - 修改主密码
    private func changePassword() {
        let a = UIAlertController(title: "修改主密码", message: "输入旧密码与两次新密码", preferredStyle: .alert)
        a.addTextField { $0.isSecureTextEntry = true; $0.placeholder = "旧密码" }
        a.addTextField { $0.isSecureTextEntry = true; $0.placeholder = "新密码（≥4位）" }
        a.addTextField { $0.isSecureTextEntry = true; $0.placeholder = "确认新密码" }
        a.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let old = a.textFields![0].text ?? ""
            let n1 = a.textFields![1].text ?? ""
            let n2 = a.textFields![2].text ?? ""
            guard self.lm.verifyMaster(old) else { self.alert("旧密码错误"); return }
            guard n1.count >= 4 else { self.alert("新密码至少 4 位"); return }
            guard n1 == n2 else { self.alert("两次新密码不一致"); return }
            self.lm.setupMasterPassword(n1)
            self.alert("主密码已更新")
        })
        a.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(a, animated: true)
    }

    private func editSecondary() {
        let a = UIAlertController(title: "二级密码（模块锁）", message: "设置后，浏览器/传话/互传/相册用二级密码解锁；留空则清除。", preferredStyle: .alert)
        a.addTextField { $0.isSecureTextEntry = true; $0.placeholder = "二级密码（≥4位，留空清除）" }
        a.addTextField { $0.isSecureTextEntry = true; $0.placeholder = "确认" }
        a.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let p = a.textFields![0].text ?? ""
            let c = a.textFields![1].text ?? ""
            if p.isEmpty { self.lm.setSecondary(nil); self.alert("已清除二级密码") ; return }
            guard p.count >= 4 else { self.alert("至少 4 位"); return }
            guard p == c else { self.alert("两次不一致"); return }
            self.lm.setSecondary(p)
            self.alert("二级密码已设置")
        })
        a.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(a, animated: true)
    }

    private func editDuress() {
        let a = UIAlertController(title: "胁迫密码", message: "在解锁页输入该密码会立即清空本机全部数据并闪退（销毁模式）。留空清除。", preferredStyle: .alert)
        a.addTextField { $0.isSecureTextEntry = true; $0.placeholder = "胁迫密码（≥4位，留空清除）" }
        a.addTextField { $0.isSecureTextEntry = true; $0.placeholder = "确认" }
        a.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let p = a.textFields![0].text ?? ""
            let c = a.textFields![1].text ?? ""
            if p.isEmpty { self.lm.setDuress(nil); self.alert("已清除胁迫密码"); return }
            guard p.count >= 4 else { self.alert("至少 4 位"); return }
            guard p == c else { self.alert("两次不一致"); return }
            self.lm.setDuress(p)
            self.alert("胁迫密码已设置")
        })
        a.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(a, animated: true)
    }

    private func alert(_ s: String) {
        let a = UIAlertController(title: nil, message: s, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "好", style: .default) { [weak self] _ in
            self?.tableView.reloadData()
        })
        present(a, animated: true)
    }
}
