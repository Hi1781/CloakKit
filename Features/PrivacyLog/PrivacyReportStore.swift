import UIKit

/// 隐私审计事件（由 iOS「App隐私报告」导出 .json/.ndjson 解析而来）
struct PrivacyEvent: Codable {
    var app: String
    var category: String   // 中文权限类别
    var raw: String        // 原始 category
    var timeText: String
    var isBackground: Bool
    var risk: Bool
    var detail: String     // 说明 / bundleID
}

/// iOS「App隐私报告」导出文件解析与本地存储
/// v4 格式为 NDJSON，每行一个扁平 JSON 对象：
/// { accessCount, accessor:{identifier,identifierType}, category, identifier, kind, timeStamp, type }
/// 兼容旧版 usageTimelines 嵌套格式。
final class PrivacyReportStore {
    static let shared = PrivacyReportStore()

    private(set) var events: [PrivacyEvent] = []
    private(set) var fileName: String?
    var pendingImportURL: URL?

    var reportDir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Reports", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    init() { load() }

    // MARK: - 导入
    func importFile(url: URL) -> Bool {
        let name = url.lastPathComponent
        let dest = reportDir.appendingPathComponent(name)
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
        } catch { /* 忽略复制失败，直接尝试解析原始 */ }

        let parsed = parseFile(dest)
        guard !parsed.isEmpty else { return false }
        events = parsed
        fileName = name
        persist()
        return true
    }

    func setImported(_ events: [PrivacyEvent], name: String) {
        self.events = events
        self.fileName = name
        persist()
    }

    // MARK: - 解析
    func parseFile(_ url: URL) -> [PrivacyEvent] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) ?? ""
        var rows: [[String: Any]] = []
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("[") {
            if let arr = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [[String: Any]] {
                rows = arr
            }
        } else {
            for line in text.components(separatedBy: "\n") {
                let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !l.isEmpty, l.hasPrefix("{"),
                      let obj = try? JSONSerialization.jsonObject(with: Data(l.utf8)) as? [String: Any] else { continue }
                rows.append(obj)
            }
        }
        return parseRows(rows)
    }

    private func parseRows(_ rows: [[String: Any]]) -> [PrivacyEvent] {
        // 归一化为候选事件（flat 或 usageTimelines）
        var cand: [(category: String, bundle: String, isBegin: Bool, date: Date?)] = []
        for obj in rows {
            if let accessor = obj["accessor"] as? [String: Any],
               let category = obj["category"] as? String {
                let bundle = (accessor["identifier"] as? String) ?? "未知"
                let kind = (obj["kind"] as? String) ?? ""
                let isBegin = kind.lowercased() == "intervalbegin"
                let date = Self.parseISO(obj["timeStamp"] as? String)
                cand.append((category, bundle, isBegin, date))
            } else if let timelines = obj["usageTimelines"] as? [[String: Any]] {
                for tl in timelines {
                    guard let items = tl["items"] as? [[String: Any]] else { continue }
                    for it in items {
                        let category = it["category"] as? String ?? "未知"
                        let bundle = it["accessor"] as? String ?? ""
                        let kind = it["kind"] as? String ?? ""
                        let ts = it["timestamp"] as? Double
                        let isBegin = kind.lowercased() == "intervalbegin"
                        cand.append((category, bundle, isBegin, ts.map { Date(timeIntervalSince1970: $0 / 1000) }))
                    }
                }
            }
        }
        // 只保留访问开始事件，并按同一应用+类别配对结束时间计算持续时间
        var beginIdx = [String: Int]()
        var beginDate = [String: Date]()
        var out: [PrivacyEvent] = []
        for c in cand {
            let key = "\(c.category)|\(c.bundle)"
            guard c.isBegin else {
                if let idx = beginIdx[key], let b = beginDate[key], let end = c.date {
                    let cur = out[idx]
                    let sec = max(0, Int(end.timeIntervalSince(b)))
                    out[idx] = PrivacyEvent(app: cur.app, category: cur.category, raw: cur.raw,
                                            timeText: cur.timeText, isBackground: false,
                                            risk: cur.risk, detail: "持续 \(sec)s · " + cur.detail)
                }
                continue
            }
            let sensitive = ["location", "camera", "microphone", "contacts"].contains(c.category.lowercased())
            let ev = PrivacyEvent(app: Self.appName(c.bundle),
                                  category: Self.categoryCN(c.category),
                                  raw: c.category,
                                  timeText: Self.fmt(c.date ?? Date()),
                                  isBackground: false,
                                  risk: sensitive,
                                  detail: c.bundle)
            out.append(ev)
            beginIdx[key] = out.count - 1
            beginDate[key] = c.date
        }
        return out
    }

    // MARK: - 字段映射
    static func categoryCN(_ raw: String) -> String {
        switch raw.lowercased() {
        case "camera": return "相机"
        case "microphone", "mic": return "麦克风"
        case "photos": return "照片"
        case "contacts": return "通讯录"
        case "location": return "位置"
        case "medialibrary": return "媒体资料库"
        default:
            if raw.contains("keychain") { return "钥匙串" }
            if raw.contains("userdefaults") { return "偏好设置" }
            if raw.contains("bluetooth") { return "蓝牙" }
            return raw
        }
    }

    static func appName(_ bundle: String) -> String {
        let map: [String: String] = [
            "com.apple.camera": "相机", "com.apple.mobileslideshow": "照片",
            "com.apple.MobileSMS": "信息", "com.apple.mobilesafari": "Safari",
            "com.apple.mobilemail": "邮件", "com.apple.mobilecal": "日历",
            "com.apple.MobileAddressBook": "通讯录", "com.apple.weather": "天气",
            "com.apple.Health": "健康", "com.apple.Maps": "地图",
            "com.apple.Music": "音乐", "com.apple.AppStore": "App Store",
            "com.apple.shortcuts": "快捷指令", "com.apple.Translate": "翻译",
            "com.bot.doubao": "豆包", "tv.danmaku.bilianime": "哔哩哔哩",
            "com.tencent.xin": "微信", "com.tencent.mqq": "QQ",
            "com.baidu.netdisk-iPad": "百度网盘", "com.quark.browser.pad": "夸克",
            "com.eeoa.ClassIn-iOS": "ClassIn", "com.fenbi.leo": "粉笔",
            "com.google.Tachyon": "Google 环聊",
        ]
        if let n = map[bundle] { return n }
        let parts = bundle.split(separator: ".")
        if bundle.hasPrefix("com.apple.") { return parts.last.map(String.init) ?? bundle }
        if parts.count >= 3 { return String(parts[2]) }
        return bundle
    }

    private static func parseISO(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s)
    }
    private static func fmt(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f.string(from: d)
    }

    // MARK: - 持久化
    private var eventsFile: URL { reportDir.appendingPathComponent("events.json") }

    func persist() {
        if let data = try? JSONEncoder().encode(events) {
            try? data.write(to: eventsFile)
        }
        UserDefaults.standard.set(fileName, forKey: "pr_report_name")
    }

    func load() {
        if let data = try? Data(contentsOf: eventsFile),
           let e = try? JSONDecoder().decode([PrivacyEvent].self, from: data) {
            events = e
        }
        fileName = UserDefaults.standard.string(forKey: "pr_report_name")
    }

    func clear() {
        events = []
        fileName = nil
        try? FileManager.default.removeItem(at: eventsFile)
        UserDefaults.standard.removeObject(forKey: "pr_report_name")
    }
}
