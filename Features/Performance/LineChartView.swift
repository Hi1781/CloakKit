import UIKit

/// 轻量折线图（CAShapeLayer 绘制，无第三方依赖）
final class LineChartView: UIView {
    private var values: [CGFloat] = []
    private let lineLayer = CAShapeLayer()
    private let fillLayer = CAShapeLayer()
    private let maxPoints = 90
    var lineColor: UIColor = .systemBlue
    var fill = true

    func append(_ v: CGFloat) {
        values.append(v)
        if values.count > maxPoints { values.removeFirst(values.count - maxPoints) }
        setNeedsLayout()
    }

    func reset() {
        values.removeAll()
        setNeedsLayout()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        lineLayer.fillColor = nil
        lineLayer.lineWidth = 2
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round
        layer.addSublayer(lineLayer)
        fillLayer.lineWidth = 0
        layer.addSublayer(fillLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !values.isEmpty, bounds.width > 20, bounds.height > 20 else {
            lineLayer.path = nil; fillLayer.path = nil; return
        }
        let w = bounds.width, h = bounds.height
        var maxV = values.max() ?? 1
        maxV = max(maxV, 0.01)
        let step = w / CGFloat(values.count)
        let path = UIBezierPath()
        for (i, v) in values.enumerated() {
            let x = CGFloat(i) * step
            let y = h - (v / maxV) * (h - 6) - 3
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        lineLayer.strokeColor = lineColor.cgColor
        lineLayer.path = path.cgPath
        if fill {
            let fp = path.copy() as! UIBezierPath
            fp.addLine(to: CGPoint(x: w, y: h))
            fp.addLine(to: CGPoint(x: 0, y: h))
            fp.close()
            fillLayer.path = fp.cgPath
            fillLayer.fillColor = lineColor.withAlphaComponent(0.15).cgColor
        } else {
            fillLayer.path = nil
        }
    }
}
