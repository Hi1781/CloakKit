import UIKit

/// 首次启动引导页（4 页滑动 + 液态玻璃风），结束后进入免责声明
final class OnboardingViewController: UIViewController, UIScrollViewDelegate {

    private let scroll = UIScrollView()
    private let pageControl = UIPageControl()
    private let nextBtn = UIButton(type: .system)

    private let pages: [(String, String, String)] = [
        ("shield.lefthalf.filled", "隐私优先的设备工具箱", "一站式查看设备信息、实时监控、审计隐私权限。所有数据仅存本机。"),
        ("waveform.path.ecg", "性能实时监控", "CPU / 内存 / 网络速率动态曲线，一目了然掌握设备状态。"),
        ("lock.shield.fill", "加密私密相册", "AES-256 加密存储，主密码 + 诱饵密码 + FaceID 多重保护。"),
        ("globe", "无痕隐私浏览", "零缓存浏览器 + Tor / VPN 连接控制面板，打造专属隐私空间。"),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        GlassTheme.installScene(on: view)

        scroll.isPagingEnabled = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.delegate = self
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.3)
        pageControl.currentPageIndicatorTintColor = GlassTheme.tint
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageControl)

        nextBtn.setTitle("继续", for: .normal)
        nextBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        nextBtn.setTitleColor(.white, for: .normal)
        nextBtn.backgroundColor = GlassTheme.tint
        nextBtn.layer.cornerRadius = 24
        nextBtn.addTarget(self, action: #selector(nextTap), for: .touchUpInside)
        nextBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nextBtn)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -16),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: nextBtn.topAnchor, constant: -20),
            nextBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nextBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            nextBtn.widthAnchor.constraint(equalToConstant: 180),
            nextBtn.heightAnchor.constraint(equalToConstant: 48),
        ])
        buildPages()
    }

    private func buildPages() {
        let content = UIStackView()
        content.axis = .horizontal
        content.spacing = 0
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.topAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            content.heightAnchor.constraint(equalTo: scroll.heightAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
        ])
        let w = view.bounds.width
        for (_, p) in pages.enumerated() {
            let page = UIView()
            page.translatesAutoresizingMaskIntoConstraints = false
            page.widthAnchor.constraint(equalToConstant: w).isActive = true

            let icon = UIImageView(image: UIImage(systemName: p.0))
            icon.tintColor = GlassTheme.tint
            icon.contentMode = .scaleAspectFit
            icon.translatesAutoresizingMaskIntoConstraints = false

            let title = UILabel()
            title.text = p.1
            title.textColor = .white
            title.font = .systemFont(ofSize: 26, weight: .bold)
            title.textAlignment = .center
            title.numberOfLines = 0

            let desc = UILabel()
            desc.text = p.2
            desc.textColor = .systemGray2
            desc.font = .systemFont(ofSize: 16)
            desc.textAlignment = .center
            desc.numberOfLines = 0

            let card = GlassTheme.glassCard(content: { let s = UIStackView(arrangedSubviews: [icon, title, desc]); s.axis = .vertical; s.spacing = 16; return s }(),
                                            radius: 24)
            card.translatesAutoresizingMaskIntoConstraints = false
            page.addSubview(card)
            NSLayoutConstraint.activate([
                card.centerXAnchor.constraint(equalTo: page.centerXAnchor),
                card.centerYAnchor.constraint(equalTo: page.centerYAnchor),
                card.widthAnchor.constraint(equalToConstant: w - 72),
                icon.heightAnchor.constraint(equalToConstant: 84),
            ])
            content.addArrangedSubview(page)
        }
        content.widthAnchor.constraint(equalToConstant: w * CGFloat(pages.count)).isActive = true
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        pageControl.currentPage = Int(scrollView.contentOffset.x / max(scrollView.bounds.width, 1))
    }

    @objc private func nextTap() {
        if pageControl.currentPage < pages.count - 1 {
            pageControl.currentPage += 1
            let x = CGFloat(pageControl.currentPage) * scroll.bounds.width
            scroll.setContentOffset(CGPoint(x: x, y: 0), animated: true)
        } else {
            let dis = DisclaimerViewController()
            dis.modalPresentationStyle = .pageSheet
            if let sheet = dis.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
            present(dis, animated: true)
        }
    }
}
