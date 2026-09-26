import UIKit

/// 简洁深色主题 —— 还原「一开始」的原始 UI（无毛玻璃、无渐变光斑、无玻璃卡片）
/// 保留原 API 名称以最小改动兼容既有调用点；仅改变视觉实现。
enum GlassTheme {

    static let tint = UIColor.systemBlue
    static let stroke = UIColor(white: 1, alpha: 0.12)

    // MARK: - 全局外观：纯色深色导航栏 / 标签栏（非透明、无毛玻璃）
    static func configureAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(white: 0.08, alpha: 1)
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(white: 0.08, alpha: 1)
        let item = UITabBarItemAppearance()
        item.normal.iconColor = UIColor.systemGray2
        item.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray2]
        item.selected.iconColor = tint
        item.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
        tab.stackedLayoutAppearance = item
        tab.inlineLayoutAppearance = item
        tab.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().isTranslucent = true
    }

    // MARK: - 场景背景：纯深色
    static func installScene(on view: UIView) {
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)
    }

    // MARK: - 深色卡片（纯色 + 圆角 + 细描边）
    static func glassCard(content: UIView? = nil, radius: CGFloat = 12) -> UIView {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.backgroundColor = UIColor(white: 0.10, alpha: 1)
        wrap.layer.cornerRadius = radius
        wrap.layer.borderWidth = 0.5
        wrap.layer.borderColor = stroke.cgColor
        if let c = content {
            c.translatesAutoresizingMaskIntoConstraints = false
            wrap.addSubview(c)
            NSLayoutConstraint.activate([
                c.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 12),
                c.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -12),
                c.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 12),
                c.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -12),
            ])
        }
        return wrap
    }

    // MARK: - 深色单元格
    static func glassCell(on cell: UITableViewCell) {
        cell.backgroundColor = UIColor(white: 0.10, alpha: 1)
    }
}
