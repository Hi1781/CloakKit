import UIKit
import Security

/// 密钥安全存储：优先 Keychain，回退 UserDefaults（侧载环境兼容）
enum SecureStore {
    private static let defs = UserDefaults.standard

    static func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.privacy.toolkit",
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(query as CFDictionary)
        let st = SecItemAdd(query as CFDictionary, nil)
        if st != errSecSuccess {
            // 回退：Keychain 不可用时落 UserDefaults（base64）
            defs.set(data.base64EncodedString(), forKey: "sec_" + key)
        }
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.privacy.toolkit",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data {
            return data
        }
        if let s = defs.string(forKey: "sec_" + key) {
            return Data(base64Encoded: s)
        }
        return nil
    }
}
