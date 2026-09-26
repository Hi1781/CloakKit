import UIKit
import Security

/// 胁迫密码触发的「一键清空 + 闪退」
/// 清除沙盒全部数据、恢复默认设置、清除本机钥匙串相关条目，随后终止进程（闪退）。
final class DataWiper {

    static func wipeAll() {
        let fm = FileManager.default
        // 1) 清空 Documents / tmp / Caches
        let dirs = [FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
                    FileManager.default.temporaryDirectory,
                    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]]
        for d in dirs {
            if let files = try? fm.contentsOfDirectory(at: d, includingPropertiesForKeys: nil) {
                for f in files { try? fm.removeItem(at: f) }
            }
        }
        // 2) 恢复默认设置（清空所有 UserDefaults）
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        UserDefaults.standard.synchronize()

        // 3) 清除本机钥匙串条目（尽力而为）
        wipeKeychain()

        // 4) 闪退
        fatalError("privacy-toolkit: duress wipe complete")
    }

    private static func wipeKeychain() {
        for service in ["privacy.toolkit.vault", "com.privacy.toolkit", "PrivacyToolkit"] {
            let q: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
            ]
            SecItemDelete(q as CFDictionary)
        }
    }
}
