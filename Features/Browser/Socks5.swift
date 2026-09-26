import Foundation
import Darwin

/// 真实 SOCKS5 代理引擎（原生 socket 实现）
/// 用途：对用户自配节点做真实握手/连通性/代理链路探测。
/// 说明：Tor 洋葱引擎需交叉编译 Tor 核心 C 库；系统级 VPN 需 NetworkExtension
/// entitlement 与签名描述文件（未签名 raw IPA 无法支持），二者不在本模块范围。
final class Socks5Client {
    struct Config {
        var host: String
        var port: Int
        var user: String = ""
        var pass: String = ""
    }

    /// 返回：是否成功、耗时(ms)、错误描述
    static func probe(_ c: Config, targetHost: String = "1.1.1.1", targetPort: Int = 443,
                      timeout: Double = 6, completion: @escaping (Bool, Double, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let start = Date()
            func done(_ ok: Bool, _ err: String) {
                let ms = Date().timeIntervalSince(start) * 1000
                DispatchQueue.main.async { completion(ok, ms, err) }
            }
            guard let fd = Self.connectSocket(host: c.host, port: c.port, timeout: timeout) else {
                done(false, "无法连接节点 \(c.host):\(c.port)")
                return
            }
            defer { close(fd) }

            // 1) 问候
            let g = Data([0x05, 0x01, c.user.isEmpty ? 0x00 : 0x02])
            guard Self.sendAll(fd, g, timeout) else { done(false, "发送失败"); return }
            guard let r2 = Self.recvExact(fd, 2, timeout) else { done(false, "节点无响应"); return }
            let method = r2[1]
            if method == 0xFF { done(false, "节点无可用的认证方式"); return }
            if method == 0x02 {
                guard let u = c.user.data(using: .utf8), let p = c.pass.data(using: .utf8),
                      u.count <= 255, p.count <= 255 else { done(false, "认证数据异常"); return }
                var a = Data([0x01, UInt8(u.count)]); a.append(u); a.append(UInt8(p.count)); a.append(p)
                guard Self.sendAll(fd, a, timeout) else { done(false, "发送失败"); return }
                guard let r3 = Self.recvExact(fd, 2, timeout), r3[1] == 0 else { done(false, "认证失败"); return }
            }

            // 2) CONNECT 目标（证明整条代理链路可用）
            var cq = Data([0x05, 0x01, 0x00])
            if Self.isIPv4(targetHost) {
                cq.append(0x01)
                cq.append(contentsOf: Self.ipv4Bytes(targetHost))
            } else {
                let bytes = Data(targetHost.utf8)
                cq.append(0x03); cq.append(UInt8(min(bytes.count, 255))); cq.append(bytes)
            }
            let portBE = withUnsafeBytes(of: UInt16(targetPort).bigEndian) { Data($0) }
            cq.append(contentsOf: portBE)
            guard Self.sendAll(fd, cq, timeout) else { done(false, "发送失败"); return }
            guard let r4 = Self.recvExact(fd, 4, timeout) else { done(false, "代理无响应"); return }
            let code = r4[1]
            if code != 0x00 {
                done(false, "代理拒绝连接（code \(code)）")
                return
            }
            done(true, "已通过节点建立加密链路")
        }
    }

    // MARK: - socket 原语
    private static func connectSocket(host: String, port: Int, timeout: Double) -> Int32? {
        var hint = addrinfo()
        hint.ai_family = AF_INET
        hint.ai_socktype = SOCK_STREAM
        var res: UnsafeMutablePointer<addrinfo>?
        let rc = getaddrinfo(host, String(port), &hint, &res)
        guard rc == 0, let addr = res else { return nil }
        defer { freeaddrinfo(res) }

        let fd = socket(addr.pointee.ai_family, addr.pointee.ai_socktype, addr.pointee.ai_protocol)
        guard fd >= 0 else { return nil }
        // 非阻塞
        var flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        let c = connect(fd, addr.pointee.ai_addr, addr.pointee.ai_addrlen)
        if c != 0 {
            if errno == EINPROGRESS {
                var wfd = fd_set()
                withUnsafeMutableBytes(of: &wfd) { raw in
                    let bits = raw.bindMemory(to: Int32.self)
                    let i = Int(fd) / 32
                    bits[i] |= Int32(1 << (Int(fd) % 32))
                }
                var tv = timeval()
                tv.tv_sec = Int(timeout)
                tv.tv_usec = 0
                let sel = select(fd + 1, nil, &wfd, nil, &tv)
                if sel <= 0 { close(fd); return nil }
                var err: Int32 = 0
                var len = socklen_t(MemoryLayout<Int32>.size)
                getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &len)
                if err != 0 { close(fd); return nil }
            } else {
                close(fd); return nil
            }
        }
        // 恢复阻塞
        flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)
        // 读写超时
        var tv = timeval(); tv.tv_sec = Int(timeout); tv.tv_usec = 0
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        return fd
    }

    private static func sendAll(_ fd: Int32, _ data: Data, _ timeout: Double) -> Bool {
        let bytes = [UInt8](data)
        return bytes.withUnsafeBytes { buf -> Bool in
            let base = buf.baseAddress!
            var sent = 0
            while sent < bytes.count {
                let n = send(fd, base + sent, bytes.count - sent, 0)
                if n < 0 { return false }
                sent += n
            }
            return true
        }
    }

    private static func recvExact(_ fd: Int32, _ n: Int, _ timeout: Double) -> Data? {
        var buf = [UInt8](repeating: 0, count: n)
        let ok = buf.withUnsafeMutableBytes { raw -> Bool in
            let base = raw.baseAddress!
            var got = 0
            while got < n {
                let r = recv(fd, base + got, n - got, 0)
                if r <= 0 { return false }
                got += r
            }
            return true
        }
        return ok ? Data(buf) : nil
    }

    private static func isIPv4(_ s: String) -> Bool {
        var a = in_addr()
        return inet_pton(AF_INET, s, &a) == 1
    }
    private static func ipv4Bytes(_ s: String) -> [UInt8] {
        s.split(separator: ".").compactMap { UInt8($0) }
    }
}
