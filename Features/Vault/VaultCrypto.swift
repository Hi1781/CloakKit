import Foundation
import CommonCrypto

/// AES-256-GCM 近似实现（CommonCrypto CCCrypt, CBC + PKCS7 + 随机IV）
/// 密钥由密码经 PBKDF2 派生，密文文件前 16 字节为 IV。
enum VaultCrypto {
    static let ivSize = 16
    static let keySize = 32
    static let saltSize = 16
    static let rounds = 20_000

    static func deriveKey(password: String, salt: Data) -> Data? {
        var key = Data(count: keySize)
        let pwd = Array(password.utf8CString)   // [CChar]
        let sal = [UInt8](salt)
        let status = key.withUnsafeMutableBytes { kb -> Int32 in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), pwd, pwd.count - 1,
                                 sal, sal.count,
                                 CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                                 UInt32(rounds),
                                 kb.baseAddress?.assumingMemoryBound(to: UInt8.self), keySize)
        }
        return status == kCCSuccess ? key : nil
    }

    static func random(_ n: Int) -> Data {
        var d = Data(count: n)
        _ = d.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, n, $0.baseAddress!) }
        return d
    }

    static func encrypt(_ plain: Data, key: Data) -> Data? {
        let iv = random(ivSize)
        var out = Data(count: plain.count + kCCBlockSizeAES128)
        var moved = 0
        let outLen = out.count
        let status = plain.withUnsafeBytes { pb in
            out.withUnsafeMutableBytes { ob in
                CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding), [UInt8](key), keySize,
                        [UInt8](iv), pb.baseAddress, plain.count,
                        ob.baseAddress, outLen, &moved)
            }
        }
        guard status == kCCSuccess else { return nil }
        out.removeSubrange(moved..<out.count)
        return iv + out
    }

    static func decrypt(_ data: Data, key: Data) -> Data? {
        guard data.count > ivSize else { return nil }
        let iv = data.subdata(in: 0..<ivSize)
        let body = data.subdata(in: ivSize..<data.count)
        var out = Data(count: body.count + kCCBlockSizeAES128)
        var moved = 0
        let outLen = out.count
        let status = body.withUnsafeBytes { pb in
            out.withUnsafeMutableBytes { ob in
                CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding), [UInt8](key), keySize,
                        [UInt8](iv), pb.baseAddress, body.count,
                        ob.baseAddress, outLen, &moved)
            }
        }
        guard status == kCCSuccess else { return nil }
        out.removeSubrange(moved..<out.count)
        return out
    }
}
