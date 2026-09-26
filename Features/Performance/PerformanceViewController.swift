import UIKit

/// 模块2 · 系统性能实时监控（CPU / 内存 / 上下行网速 动态曲线）
final class PerformanceViewController: UIViewController {

    private let monitor = SystemMonitor()
    private var timer: Timer?

    private let cpuChart = LineChartView()
    private let memChart = LineChartView()
    private let netChart = LineChartView()

    private let cpuLabel = UILabel()
    private let memLabel = UILabel()
    private let netLabel = UILabel()

    private let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "性能监控"
        GlassTheme.installScene(on: view)
        build()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startTimer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }

    deinit { stopTimer() }

    private func startTimer() {
        guard timer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick() // 立即出一次数据，避免返回时空白
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func card(title: String, chart: LineChartView, label: UILabel) -> UIView {
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 8
        let t = UILabel()
        t.text = title
        t.font = .systemFont(ofSize: 14, weight: .medium)
        t.textColor = .systemGray2
        label.font = .monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.text = "—"
        chart.lineColor = .systemBlue
        chart.heightAnchor.constraint(equalToConstant: 110).isActive = true
        content.addArrangedSubview(t)
        content.addArrangedSubview(label)
        content.addArrangedSubview(chart)
        return GlassTheme.glassCard(content: content, radius: 18)
    }

    private func build() {
        cpuChart.lineColor = .systemGreen
        memChart.lineColor = .systemOrange
        netChart.lineColor = .systemPurple

        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
        stack.addArrangedSubview(card(title: "CPU 占用率", chart: cpuChart, label: cpuLabel))
        stack.addArrangedSubview(card(title: "内存占用", chart: memChart, label: memLabel))
        stack.addArrangedSubview(card(title: "网络速率（下行/上行）", chart: netChart, label: netLabel))
    }

    private func tick() {
        let s = monitor.sample()
        cpuLabel.text = String(format: "%.0f%%", s.cpu)
        memLabel.text = s.memText
        netLabel.text = String(format: "↓%.0f / ↑%.0f KB/s", s.netDown, s.netUp)
        cpuChart.append(CGFloat(s.cpu))
        memChart.append(CGFloat(s.memUsed))
        netChart.append(CGFloat(max(s.netDown, s.netUp)))
    }
}
