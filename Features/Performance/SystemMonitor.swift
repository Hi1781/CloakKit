import UIKit
import Darwin

/// 系统采样器：CPU 占用率 / 内存占用 / 网络上下行速率
/// 基于 mach host_processor_info / host_statistics64 / getifaddrs，无需私有 API
struct SystemSample {
    var cpu: Double = 0      // 0~100
    var memUsed: Double = 0  // 0~100
    var memText: String = ""
    var netUp: Double = 0    // KB/s
    var netDown: Double = 0  // KB/s
}

final class SystemMonitor {
    private var lastCPU: (tick: UInt64, total: UInt64) = (0, 0)
    private var lastBytes: (rx: UInt64, tx: UInt64) = (0, 0)
    private var lastTime: TimeInterval = 0
    private let physical = Double(ProcessInfo.processInfo.physicalMemory)

    func sample() -> SystemSample {
        var s = SystemSample()
        // CPU
        let cpu = cpuTicks()
        s.cpu = cpuUsage(last: lastCPU, cur: cpu)
        lastCPU = cpu
        // 内存
        let mem = memoryUsed()
        s.memUsed = mem.pct
        s.memText = mem.text
        // 网络
        let now = Date().timeIntervalSince1970
        let bytes = networkBytes()
        if lastTime > 0 {
            let dt = now - lastTime
            if dt > 0.3 {
                s.netDown = Double(bytes.rx > lastBytes.rx ? bytes.rx - lastBytes.rx : 0) / 1024 / dt
                s.netUp   = Double(bytes.tx > lastBytes.tx ? bytes.tx - lastBytes.tx : 0) / 1024 / dt
            }
        }
        lastBytes = bytes
        lastTime = now
        return s
    }

    // MARK: - CPU
    private func cpuTicks() -> (tick: UInt64, total: UInt64) {
        var info: processor_info_array_t?
        var numCpu: natural_t = 0
        var numInfo: mach_msg_type_number_t = 0
        let err = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpu, &info, &numInfo)
        guard err == KERN_SUCCESS, let arr = info else { return (0, 0) }
        var tick: UInt64 = 0, total: UInt64 = 0
        for i in 0..<Int(numCpu) {
            let base = i * Int(CPU_STATE_MAX)
            let user = Int(arr[base + Int(CPU_STATE_USER)])
            let system = Int(arr[base + Int(CPU_STATE_SYSTEM)])
            let nice = Int(arr[base + Int(CPU_STATE_NICE)])
            let idle = Int(arr[base + Int(CPU_STATE_IDLE)])
            tick += UInt64(user + system + nice)
            total += UInt64(user + system + nice + idle)
        }
        let sz = vm_size_t(Int(numCpu) * Int(CPU_STATE_MAX))
        vm_deallocate(mach_task_self_, UInt(bitPattern: arr), sz)
        return (tick, total)
    }

    private func cpuUsage(last: (UInt64, UInt64), cur: (UInt64, UInt64)) -> Double {
        let dt = cur.1 - last.1
        guard dt > 0 else { return 0 }
        return Double(cur.0 - last.0) / Double(dt) * 100
    }

    // MARK: - 内存
    private func memoryUsed() -> (pct: Double, text: String) {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let err = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard err == KERN_SUCCESS else { return (0, "—") }
        let page = Double(vm_kernel_page_size)
        let free = Double(stats.free_count) * page
        let used = physical - free
        let pct = physical > 0 ? used / physical * 100 : 0
        let gb = String(format: "%.1f / %.1f GB", used / 1_073_741_824, physical / 1_073_741_824)
        return (min(pct, 100), gb)
    }

    // MARK: - 网络
    private func networkBytes() -> (rx: UInt64, tx: UInt64) {
        var rx: UInt64 = 0, tx: UInt64 = 0
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        var ptr = ifaddr
        while ptr != nil {
            let ifa = ptr!.pointee
            let family = ifa.ifa_addr.pointee.sa_family
            if family == UInt8(AF_LINK) {
                if let data = ifa.ifa_data {
                    let bytes = data.assumingMemoryBound(to: if_data.self).pointee
                    rx += UInt64(bytes.ifi_ibytes)
                    tx += UInt64(bytes.ifi_obytes)
                }
            }
            ptr = ifa.ifa_next
        }
        freeifaddrs(ifaddr)
        return (rx, tx)
    }
}
