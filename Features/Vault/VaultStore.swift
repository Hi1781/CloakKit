import UIKit

/// 加密相册存储：文件密文落盘到沙盒 Documents/Vault
/// 每条记录存一个 json（原扩展名），图片存为 <uuid>.bin（密文）
final class VaultStore {
    static let shared = VaultStore()
    private let fm = FileManager.default

    var vaultDir: URL {
        let d = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Vault", isDirectory: true)
        try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    struct Item {
        let id: String
        let ext: String
        let name: String
        let size: Int
    }

    func list() -> [Item] {
        let jsons = (try? fm.contentsOfDirectory(atPath: vaultDir.path))?
            .filter { $0.hasSuffix(".json") } ?? []
        return jsons.compactMap { f in
            let url = vaultDir.appendingPathComponent(f)
            guard let data = try? Data(contentsOf: url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = obj["id"] as? String else { return nil }
            let ext = obj["ext"] as? String ?? "png"
            let name = obj["name"] as? String ?? id
            let bin = vaultDir.appendingPathComponent(id + ".bin")
            let size = (try? fm.attributesOfItem(atPath: bin.path)[.size] as? Int) ?? 0
            return Item(id: id, ext: ext, name: name, size: size)
        }
        .sorted { $0.id < $1.id }
    }

    func save(imageData: Data, name: String, key: Data) -> Bool {
        guard let enc = VaultCrypto.encrypt(imageData, key: key) else { return false }
        let id = UUID().uuidString
        let ext = (name as NSString).pathExtension.isEmpty ? "png" : (name as NSString).pathExtension
        do {
            try enc.write(to: vaultDir.appendingPathComponent(id + ".bin"))
            let meta: [String: Any] = ["id": id, "ext": ext, "name": name]
            let jd = try JSONSerialization.data(withJSONObject: meta)
            try jd.write(to: vaultDir.appendingPathComponent(id + ".json"))
            return true
        } catch {
            return false
        }
    }

    func image(for item: Item, key: Data) -> UIImage? {
        let url = vaultDir.appendingPathComponent(item.id + ".bin")
        guard let data = try? Data(contentsOf: url),
              let plain = VaultCrypto.decrypt(data, key: key) else { return nil }
        return UIImage(data: plain)
    }

    func delete(_ item: Item) {
        try? fm.removeItem(at: vaultDir.appendingPathComponent(item.id + ".bin"))
        try? fm.removeItem(at: vaultDir.appendingPathComponent(item.id + ".json"))
    }
}
