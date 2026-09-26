import UIKit
import LocalAuthentication

/// 主密码 + 二级密码 + 胁迫密码 + 生物识别开关 + 后台锁定开关 + 模块锁状态
final class LockManager {
    static let shared = LockManager()
    private let defs = UserDefaults.standard
    private var unlockedModules = Set<String>()

    // MARK: - 主密码
    var hasAppLock: Bool { defs.data(forKey: "applock_salt") != nil }

    var appUnlocked: Bool {
        get { defs.bool(forKey: "applock_session") }
        set { defs.set(newValue, forKey: "applock_session") }
    }
    /// 是否处于胁迫密码触发的安全空壳模式
    var decoyActive: Bool {
        get { defs.bool(forKey: "decoy_active") }
        set { defs.set(newValue, forKey: "decoy_active") }
    }

    func setupMasterPassword(_ pwd: String) {
        write(pwd: pwd, saltKey: "applock_salt", hashKey: "applock_hash")
        appUnlocked = true
        unlockedModules.removeAll()
    }

    func verifyMaster(_ pwd: String) -> Bool {
        verify(pwd: pwd, saltKey: "applock_salt", hashKey: "applock_hash")
    }

    // MARK: - 二级密码（模块锁用）
    var hasSecondary: Bool { defs.data(forKey: "sec_salt") != nil }
    func setSecondary(_ pwd: String?) {
        if let p = pwd, !p.isEmpty { write(pwd: p, saltKey: "sec_salt", hashKey: "sec_hash") }
        else { defs.removeObject(forKey: "sec_salt"); defs.removeObject(forKey: "sec_hash") }
        unlockedModules.removeAll()
    }
    func verifySecondary(_ pwd: String) -> Bool {
        guard hasSecondary else { return false }
        return verify(pwd: pwd, saltKey: "sec_salt", hashKey: "sec_hash")
    }

    // MARK: - 胁迫密码（触发后进入安全空壳）
    var hasDuress: Bool { defs.data(forKey: "duress_salt") != nil }
    func setDuress(_ pwd: String?) {
        if let p = pwd, !p.isEmpty { write(pwd: p, saltKey: "duress_salt", hashKey: "duress_hash") }
        else { defs.removeObject(forKey: "duress_salt"); defs.removeObject(forKey: "duress_hash") }
    }
    func verifyDuress(_ pwd: String) -> Bool {
        guard hasDuress else { return false }
        return verify(pwd: pwd, saltKey: "duress_salt", hashKey: "duress_hash")
    }
    /// 应用解锁：返回 nil=未匹配；.ok=主密码；.duress=胁迫密码
    enum UnlockResult { case ok, duress, none }
    func verifyUnlock(_ pwd: String) -> UnlockResult {
        if verifyDuress(pwd) { return .duress }
        if verifyMaster(pwd) { return .ok }
        return .none
    }

    // MARK: - 开关
    var useBiometrics: Bool {
        get { defs.object(forKey: "use_biometrics") as? Bool ?? true }
        set { defs.set(newValue, forKey: "use_biometrics") }
    }
    var autoLockOnBackground: Bool {
        get { defs.object(forKey: "autolock_bg") as? Bool ?? true }
        set { defs.set(newValue, forKey: "autolock_bg") }
    }
    static func canUseBiometrics() -> Bool {
        var err: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }
    static func biometricPrompt(reason: String, _ done: @escaping (Bool) -> Void) {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            done(false); return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { ok, _ in
            DispatchQueue.main.async { done(ok) }
        }
    }

    // MARK: - 模块锁（浏览器 / 传话 / 互传 / 相册）
    func isModuleUnlocked(_ key: String) -> Bool { unlockedModules.contains(key) }
    func unlockModule(_ key: String) { unlockedModules.insert(key) }
    func lockModule(_ key: String) { unlockedModules.remove(key) }

    // MARK: - 每模块独立密码（可选；未设置则回退主密码）
    func hasModulePassword(_ key: String) -> Bool { defs.data(forKey: "mod_\(key)_salt") != nil }
    func setModulePassword(_ key: String, _ pwd: String?) {
        if let p = pwd, !p.isEmpty {
            write(pwd: p, saltKey: "mod_\(key)_salt", hashKey: "mod_\(key)_hash")
        } else {
            defs.removeObject(forKey: "mod_\(key)_salt")
            defs.removeObject(forKey: "mod_\(key)_hash")
        }
        unlockedModules.remove(key)
    }
    func verifyModulePassword(_ key: String, _ pwd: String) -> Bool {
        guard hasModulePassword(key) else { return false }
        return verify(pwd: pwd, saltKey: "mod_\(key)_salt", hashKey: "mod_\(key)_hash")
    }

    // MARK: - 每模块诱饵密码（照搬私密相册：诱饵→进入空壳）
    func hasModuleDecoy(_ key: String) -> Bool { defs.data(forKey: "mod_\(key)_decoy_salt") != nil }
    func setModuleDecoy(_ key: String, _ pwd: String?) {
        if let p = pwd, !p.isEmpty {
            write(pwd: p, saltKey: "mod_\(key)_decoy_salt", hashKey: "mod_\(key)_decoy_hash")
        } else {
            defs.removeObject(forKey: "mod_\(key)_decoy_salt")
            defs.removeObject(forKey: "mod_\(key)_decoy_hash")
        }
        unlockedModules.remove(key)
    }
    func verifyModuleDecoy(_ key: String, _ pwd: String) -> Bool {
        guard hasModuleDecoy(key) else { return false }
        return verify(pwd: pwd, saltKey: "mod_\(key)_decoy_salt", hashKey: "mod_\(key)_decoy_hash")
    }

    // MARK: - 基础哈希工具
    private func write(pwd: String, saltKey: String, hashKey: String) {
        let salt = VaultCrypto.random(VaultCrypto.saltSize)
        let key = VaultCrypto.deriveKey(password: pwd, salt: salt) ?? Data()
        defs.set(salt, forKey: saltKey)
        defs.set(key.map { String(format: "%02x", $0) }.joined(), forKey: hashKey)
    }
    private func verify(pwd: String, saltKey: String, hashKey: String) -> Bool {
        guard let salt = defs.data(forKey: saltKey),
              let hash = defs.string(forKey: hashKey),
              let k = VaultCrypto.deriveKey(password: pwd, salt: salt) else { return false }
        return k.map { String(format: "%02x", $0) }.joined() == hash
    }
}
