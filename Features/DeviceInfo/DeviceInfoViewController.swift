import UIKit
import AppTrackingTransparency
import Security
import SystemConfiguration

/// 模块1 · 设备信息检测中心
/// IDFA / 硬件 / 系统 / 电池 / 网络 / 导出
final class DeviceInfoViewController: UITableViewController {

    private struct Row { let label: String; let value: String }
    private struct Section { let title: String; var rows: [Row] }
    private var sections: [Section] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设备信息"
        GlassTheme.installScene(on: view)
        UIDevice.current.isBatteryMonitoringEnabled = true
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain, target: self, action: #selector(exportReport))
        navigationItem.rightBarButtonItem?.tintColor = .systemBlue
        reload()
    }

    private func reload() {
        sections = [
            Section(title: "广告标识 IDFA", rows: idfaRows()),
            Section(title: "硬件信息", rows: hardwareRows()),
            Section(title: "系统信息", rows: systemRows()),
            Section(title: "电池", rows: batteryRows()),
            Section(title: "网络", rows: networkRows()),
        ]
        tableView.reloadData()
    }

    // MARK: - IDFA
    private func idfaRows() -> [Row] {
        let status: String
        let idfa: String
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .authorized:
            status = "已授权追踪"
            idfa = UIDevice.current.identifierForVendor?.uuidString ?? "—"
        case .denied:
            status = "已拒绝追踪"; idfa = "不可用（未授权）"
        case .restricted:
            status = "受限制"; idfa = "不可用"
        case .notDetermined:
            status = "未请求"; idfa = "尚未请求授权"
        @unknown default:
            status = "未知"; idfa = "—"
        }
        return [
            Row(label: "追踪状态", value: status),
            Row(label: "标识符", value: idfa),
        ]
    }

    // MARK: - 硬件
    private func hardwareRows() -> [Row] {
        let dev = UIDevice.current
        let mem = ProcessInfo.processInfo.physicalMemory / (1024*1024*1024)
        let fs: (total: UInt64, free: UInt64) = diskSpace()
        return [
            Row(label: "机型", value: modelName()),
            Row(label: "别名", value: dev.name),
            Row(label: "系统", value: "\(dev.systemName) \(dev.systemVersion)"),
            Row(label: "总内存", value: String(format: "%.0f GB", Double(mem))),
            Row(label: "存储总量", value: byteStr(fs.total)),
            Row(label: "剩余空间", value: byteStr(fs.free)),
        ]
    }

    private func systemRows() -> [Row] {
        return [
            Row(label: "设备标识", value: UIDevice.current.identifierForVendor?.uuidString ?? "—"),
            Row(label: "内核", value: ProcessInfo.processInfo.operatingSystemVersionString),
            Row(label: "处理器数", value: "\(ProcessInfo.processInfo.activeProcessorCount) 核"),
            Row(label: "架构", value: "arm64"),
        ]
    }

    // MARK: - 电池
    private func batteryRows() -> [Row] {
        let dev = UIDevice.current
        let level: Int = dev.batteryLevel >= 0 ? Int(dev.batteryLevel * 100) : -1
        let state: String
        switch dev.batteryState {
        case .charging: state = "充电中"
        case .full: state = "已充满"
        case .unplugged: state = "未充电"
        default: state = "未知"
        }
        return [
            Row(label: "电量", value: level >= 0 ? "\(level)%" : "不可用"),
            Row(label: "充电状态", value: state),
            Row(label: "监控", value: "需开启系统显示电池百分比"),
        ]
    }

    // MARK: - 网络
    private func networkRows() -> [Row] {
        let ip = localIP() ?? "—"
        let wifi = isWifi() ? "Wi-Fi" : (isCellular() ? "蜂窝网络" : "未知")
        return [
            Row(label: "连接方式", value: wifi),
            Row(label: "运营商", value: "蜂窝制式（运营商名需系统授权）"),
            Row(label: "本地IP", value: ip),
        ]
    }

    // MARK: - 表格
    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 副标题样式：左侧标签 + 右侧值（detailTextLabel），需用 .subtitle 而非默认样式
        let c = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let row = sections[indexPath.section].rows[indexPath.row]
        c.textLabel?.text = row.label
        c.textLabel?.font = .systemFont(ofSize: 15)
        c.textLabel?.textColor = .white
        c.detailTextLabel?.text = row.value
        c.detailTextLabel?.numberOfLines = 0
        c.detailTextLabel?.textColor = .systemGray2
        GlassTheme.glassCell(on: c)
        return c
    }

    // MARK: - 工具
    private func modelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let id = mirror.children.reduce("") { partial, el in
            guard let val = el.value as? Int8, val != 0 else { return partial }
            return partial + String(UnicodeScalar(UInt8(val)))
        }
        return id
    }

    private func diskSpace() -> (UInt64, UInt64) {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let v = try? url.resourceValues(forKeys: keys) else { return (0, 0) }
        return (UInt64(v.volumeTotalCapacity ?? 0), UInt64(v.volumeAvailableCapacityForImportantUsage ?? 0))
    }

    private func byteStr(_ b: UInt64) -> String {
        let gb = Double(b) / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }

    private func localIP() -> String? {
        var addr: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        var ptr = ifaddr
        while ptr != nil {
            let ifa = ptr!.pointee
            let family = ifa.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: ifa.ifa_name)
                if name == "en0" || name == "pdp_ip0" {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(ifa.ifa_addr, socklen_t(ifa.ifa_addr.pointee.sa_len),
                                &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                    addr = String(cString: host)
                }
            }
            ptr = ifa.ifa_next
        }
        freeifaddrs(ifaddr)
        return addr
    }

    private func isWifi() -> Bool {
        guard let reach = SCNetworkReachabilityCreateWithName(nil, "www.apple.com") else { return false }
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reach, &flags)
        return flags.contains(.isWWAN) == false
    }
    private func isCellular() -> Bool {
        guard let reach = SCNetworkReachabilityCreateWithName(nil, "www.apple.com") else { return false }
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reach, &flags)
        return flags.contains(.isWWAN)
    }

    @objc private func exportReport() {
        var text = "隐私工具箱 · 设备报告\n====================\n"
        for s in sections {
            text += "\n【\(s.title)】\n"
            for r in s.rows { text += "\(r.label): \(r.value)\n" }
        }
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        av.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(av, animated: true)
    }
}
