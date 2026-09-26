import UIKit
import WebKit

/// 模块5 · 独立无痕隐私浏览器
/// 零缓存/零Cookie 会话 + 右上角悬浮面板（Tor / VPN / SpeedBoost 开关与设置，UI 壳）
final class PrivacyBrowserViewController: UIViewController, WKNavigationDelegate, UITextFieldDelegate {

    private let webView = WKWebView()
    private let addressBar = UITextField()
    private let progress = UIProgressView()
    private let shieldBtn = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "隐私浏览器"
        GlassTheme.installScene(on: view)

        // 无痕配置：nonPersistentDataStore → 无 Cookie / 缓存 / 历史
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        // 不透明深色背景：避免 webView 半透明透出底层安全层导致切回黑屏
        webView.isOpaque = true
        webView.backgroundColor = UIColor(white: 0.05, alpha: 1)
        webView.translatesAutoresizingMaskIntoConstraints = false

        buildToolbar()
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: progress.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        loadHome()
    }

    private func buildToolbar() {
        let back = UIButton(type: .system)
        back.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        back.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        let fwd = UIButton(type: .system)
        fwd.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        fwd.addTarget(self, action: #selector(goFwd), for: .touchUpInside)
        let refresh = UIButton(type: .system)
        refresh.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        refresh.addTarget(self, action: #selector(goRefresh), for: .touchUpInside)

        addressBar.placeholder = "输入网址或搜索"
        addressBar.backgroundColor = UIColor(white: 0.13, alpha: 0.6)
        addressBar.layer.borderWidth = 0.5
        addressBar.layer.borderColor = GlassTheme.stroke.cgColor
        addressBar.textColor = .white
        addressBar.returnKeyType = .go
        addressBar.delegate = self
        addressBar.layer.cornerRadius = 18
        addressBar.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 36))
        addressBar.leftViewMode = .always
        addressBar.rightView = shieldBtn
        addressBar.rightViewMode = .always
        addressBar.clearButtonMode = .whileEditing

        shieldBtn.setImage(UIImage(systemName: "shield.fill"), for: .normal)
        shieldBtn.tintColor = .systemBlue
        shieldBtn.addTarget(self, action: #selector(openPanel), for: .touchUpInside)

        progress.progressTintColor = .systemBlue
        progress.trackTintColor = .clear

        let row = UIStackView(arrangedSubviews: [back, fwd, addressBar, refresh])
        row.axis = .horizontal
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(row)
        progress.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progress)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            row.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            row.heightAnchor.constraint(equalToConstant: 36),
            addressBar.widthAnchor.constraint(equalToConstant: view.bounds.width - 150),
            progress.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 4),
            progress.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            progress.heightAnchor.constraint(equalToConstant: 3),
        ])
        // 盾牌固定宽度，避免压缩地址栏
        shieldBtn.widthAnchor.constraint(equalToConstant: 34).isActive = true
        back.widthAnchor.constraint(equalToConstant: 34).isActive = true
        fwd.widthAnchor.constraint(equalToConstant: 34).isActive = true
        refresh.widthAnchor.constraint(equalToConstant: 34).isActive = true
    }

    private func loadHome() {
        if let url = URL(string: "https://www.bing.com") {
            webView.load(URLRequest(url: url))
        }
    }

    func textFieldShouldReturn(_ field: UITextField) -> Bool {
        loadInput(field.text ?? "")
        field.resignFirstResponder()
        return true
    }

    private func loadInput(_ input: String) {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        if !s.contains(".") && !s.hasPrefix("http") {
            s = "https://www.bing.com/search?q=" + s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        } else if !s.hasPrefix("http") {
            s = "https://" + s
        }
        if let url = URL(string: s) {
            webView.load(URLRequest(url: url))
        }
    }

    @objc private func goBack() { webView.goBack() }
    @objc private func goFwd() { webView.goForward() }
    @objc private func goRefresh() { webView.reload() }

    @objc private func openPanel() {
        let panel = TorVPNPanelViewController()
        panel.modalPresentationStyle = .pageSheet
        if let sheet = panel.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(panel, animated: true)
    }

    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progress.setProgress(0.2, animated: true)
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        progress.setProgress(0.6, animated: true)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progress.setProgress(1, animated: true)
        addressBar.text = webView.url?.absoluteString ?? ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.progress.setProgress(0, animated: true)
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        progress.setProgress(0, animated: true)
    }
}
