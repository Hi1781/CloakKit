import UIKit
import UniformTypeIdentifiers

/// 模块3 · 隐私权限审计
/// 无预设内容；通过「导入」或系统「打开方式/分享」加载 iOS App隐私报告 .json 并解析
final class PrivacyLogViewController: UITableViewController, UIDocumentPickerDelegate {

    private var events: [PrivacyEvent] = []
    private var summaryLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "隐私审计"
        GlassTheme.installScene(on: view)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none

        let importBtn = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"),
                                        style: .plain, target: self, action: #selector(importTap))
        let clearBtn = UIBarButtonItem(image: UIImage(systemName: "trash"),
                                       style: .plain, target: self, action: #selector(clear))
        navigationItem.rightBarButtonItems = [importBtn, clearBtn]
        importBtn.tintColor = GlassTheme.tint
        clearBtn.tintColor = .systemGray

        buildHeader()
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 消费「打开方式/分享」传入的文件
        if let url = PrivacyReportStore.shared.pendingImportURL {
            PrivacyReportStore.shared.pendingImportURL = nil
            handleImport(url)
        }
    }

    private func buildHeader() {
        let h = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        summaryLabel.frame = h.bounds.insetBy(dx: 16, dy: 10)
        summaryLabel.font = .systemFont(ofSize: 13)
        summaryLabel.textColor = .systemGray2
        summaryLabel.numberOfLines = 0
        h.addSubview(summaryLabel)
        tableView.tableHeaderView = h
    }

    @objc private func importTap() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json, UTType.data],
                                                    asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        handleImport(url)
    }

    private func handleImport(_ url: URL) {
        let ok = PrivacyReportStore.shared.importFile(url: url)
        reload()
        if !ok {
            let a = UIAlertController(title: "解析失败",
                                      message: "未能从该文件中解析出隐私访问记录。请从「设置-隐私与安全-App隐私报告-分享」导出 .json 后导入。",
                                      preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "好", style: .default))
            present(a, animated: true)
        }
    }

    @objc private func clear() {
        PrivacyReportStore.shared.clear()
        reload()
    }

    private func reload() {
        events = PrivacyReportStore.shared.events
        let name = PrivacyReportStore.shared.fileName ?? ""
        if events.isEmpty {
            summaryLabel.text = "尚无数据。\n① 在「设置-隐私与安全-App隐私报告」开启记录\n② 点击右上角「分享」导出 .json\n③ 点击左上角导入按钮，或直接用本 App 打开该 .json"
        } else {
            let bg = events.filter { $0.isBackground }.count
            let risk = events.filter { $0.risk }.count
            summaryLabel.text = "已导入：\(name)\n共 \(events.count) 条 · 后台访问 \(bg) · 风险标记 \(risk)\n（红色=后台偷调敏感权限）"
        }
        tableView.reloadData()
    }

    // MARK: - Table
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        events.isEmpty ? 0 : events.count
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        events.isEmpty ? nil : "权限访问事件"
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let e = events[indexPath.row]
        c.textLabel?.text = e.app + " · " + e.category
        c.textLabel?.font = .systemFont(ofSize: 15)
        c.textLabel?.numberOfLines = 1
        var detail = e.timeText
        if e.isBackground { detail += " · 后台" }
        if !e.detail.isEmpty { detail += " · " + e.detail }
        c.detailTextLabel?.text = detail
        c.detailTextLabel?.textColor = .systemGray2
        c.detailTextLabel?.numberOfLines = 0
        GlassTheme.glassCell(on: c)
        if e.risk {
            c.textLabel?.textColor = .systemRed
            c.imageView?.image = UIImage(systemName: "exclamationmark.triangle.fill")
            c.imageView?.tintColor = .systemRed
        } else {
            c.textLabel?.textColor = .white
            c.imageView?.image = UIImage(systemName: e.isBackground ? "moon.fill" : "checkmark.circle")
            c.imageView?.tintColor = e.isBackground ? .systemOrange : .systemGreen
        }
        return c
    }
}
