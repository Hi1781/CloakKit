import UIKit
import LocalAuthentication
import PhotosUI
import Photos
import UniformTypeIdentifiers

/// 模块4 · 独立加密私密相册
/// 数字/诱饵密码 + FaceID 解锁；AES-256 加密存储；与浏览器完全隔离
final class VaultViewController: UIViewController {

    private enum State { case locked, unlocked, decoy }
    private var state: State = .locked

    private let store = VaultStore.shared
    private var items: [VaultStore.Item] = []
    private var key: Data?
    private var cache: [String: UIImage] = [:]

    private let passField = UITextField()
    private let unlockBtn = UIButton(type: .system)
    private let faceBtn = UIButton(type: .system)
    private let hintLabel = UILabel()
    private var gallery: UICollectionView?

    private let defs = UserDefaults.standard
    private var saltReal: Data { defs.data(forKey: "v_salt_real") ?? Data() }
    private var hashReal: String { defs.string(forKey: "v_hash_real") ?? "" }
    private var saltDecoy: Data { defs.data(forKey: "v_salt_decoy") ?? Data() }
    private var hashDecoy: String { defs.string(forKey: "v_hash_decoy") ?? "" }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "私密相册"
        GlassTheme.installScene(on: view)
        if hashReal.isEmpty || saltReal.isEmpty {
            showSetup()
        } else {
            showLock()
        }
    }

    // MARK: - 首次设置密码
    private func showSetup() {
        view.subviews.forEach { $0.removeFromSuperview() }
        let t = UILabel()
        t.text = "首次使用：设置私密相册密码"
        t.textColor = .white
        t.font = .systemFont(ofSize: 20, weight: .semibold)
        t.numberOfLines = 0
        let note = UILabel()
        note.text = "设置板块主密码，可另设诱饵密码。输入诱饵密码时进入空壳页面。"
        note.textColor = .systemGray2
        note.font = .systemFont(ofSize: 13)
        note.numberOfLines = 0

        passField.placeholder = "主密码（≥4位）"
        passField.isSecureTextEntry = true
        passField.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        passField.layer.borderWidth = 0.5
        passField.layer.borderColor = GlassTheme.stroke.cgColor
        passField.textColor = .white
        passField.layer.cornerRadius = 8
        passField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 40))
        passField.leftViewMode = .always

        let masterConfirm = UITextField()
        masterConfirm.placeholder = "确认主密码"
        masterConfirm.isSecureTextEntry = true
        masterConfirm.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        masterConfirm.layer.borderWidth = 0.5
        masterConfirm.layer.borderColor = GlassTheme.stroke.cgColor
        masterConfirm.textColor = .white
        masterConfirm.layer.cornerRadius = 8
        masterConfirm.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 40))
        masterConfirm.leftViewMode = .always

        let decoy = UITextField()
        decoy.placeholder = "诱饵密码（≥4位）"
        decoy.isSecureTextEntry = true
        decoy.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        decoy.layer.borderWidth = 0.5
        decoy.layer.borderColor = GlassTheme.stroke.cgColor
        decoy.textColor = .white
        decoy.layer.cornerRadius = 8
        decoy.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 40))
        decoy.leftViewMode = .always

        let decoyConfirm = UITextField()
        decoyConfirm.placeholder = "确认诱饵密码"
        decoyConfirm.isSecureTextEntry = true
        decoyConfirm.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        decoyConfirm.layer.borderWidth = 0.5
        decoyConfirm.layer.borderColor = GlassTheme.stroke.cgColor
        decoyConfirm.textColor = .white
        decoyConfirm.layer.cornerRadius = 8
        decoyConfirm.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 40))
        decoyConfirm.leftViewMode = .always

        let done = UIButton(type: .system)
        done.setTitle("创建", for: .normal)
        done.backgroundColor = .systemBlue
        done.setTitleColor(.white, for: .normal)
        done.layer.cornerRadius = 8
        done.addTarget(self, action: #selector(setupDone(_:)), for: .touchUpInside)

        hintLabel.text = " "
        hintLabel.textColor = .systemRed
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.numberOfLines = 0

        let v = UIStackView(arrangedSubviews: [t, note, passField, masterConfirm, decoy, decoyConfirm, hintLabel, done])
        v.axis = .vertical
        v.spacing = 14
        v.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(v)
        NSLayoutConstraint.activate([
            v.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            v.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            v.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            passField.heightAnchor.constraint(equalToConstant: 44),
            masterConfirm.heightAnchor.constraint(equalToConstant: 44),
            decoy.heightAnchor.constraint(equalToConstant: 44),
            decoyConfirm.heightAnchor.constraint(equalToConstant: 44),
            done.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    @objc private func setupDone(_ sender: UIButton) {
        guard let v = sender.superview as? UIStackView else { return }
        let p = (v.arrangedSubviews[2] as! UITextField).text ?? ""
        let c = (v.arrangedSubviews[3] as! UITextField).text ?? ""
        let d = (v.arrangedSubviews[4] as! UITextField).text ?? ""
        let dc = (v.arrangedSubviews[5] as! UITextField).text ?? ""
        guard p.count >= 4, d.count >= 4 else { hintLabel.text = "主密码与诱饵密码均需 ≥4 位"; return }
        guard p == c else { hintLabel.text = "两次主密码不一致"; return }
        guard d == dc else { hintLabel.text = "两次诱饵密码不一致"; return }
        guard d != p else { hintLabel.text = "诱饵密码不能与主密码相同"; return }

        func persist(_ pwd: String) -> (Data, String) {
            let salt = VaultCrypto.random(VaultCrypto.saltSize)
            let k = VaultCrypto.deriveKey(password: pwd, salt: salt)!
            return (salt, k.map { String(format: "%02x", $0) }.joined())
        }
        let (sr, hr) = persist(p)
        let (sd, hd) = persist(d)
        defs.set(sr, forKey: "v_salt_real"); defs.set(hr, forKey: "v_hash_real")
        defs.set(sd, forKey: "v_salt_decoy"); defs.set(hd, forKey: "v_hash_decoy")
        // 持久化主密钥，供 FaceID/指纹免密解锁取用
        SecureStore.save(key: "vault_key", data: VaultCrypto.deriveKey(password: p, salt: sr)!)
        showLock()
    }

    // MARK: - 锁屏
    private func showLock() {
        view.subviews.forEach { $0.removeFromSuperview() }
        gallery = nil
        let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit

        passField.placeholder = "输入密码"
        passField.isSecureTextEntry = true
        passField.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        passField.layer.borderWidth = 0.5
        passField.layer.borderColor = GlassTheme.stroke.cgColor
        passField.textColor = .white
        passField.layer.cornerRadius = 8
        passField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 40))
        passField.leftViewMode = .always
        passField.returnKeyType = .go
        passField.addTarget(self, action: #selector(enterPass), for: .editingDidEndOnExit)

        unlockBtn.setTitle("解锁", for: .normal)
        unlockBtn.backgroundColor = .systemBlue
        unlockBtn.setTitleColor(.white, for: .normal)
        unlockBtn.layer.cornerRadius = 8
        unlockBtn.addTarget(self, action: #selector(enterPass), for: .touchUpInside)

        faceBtn.setImage(UIImage(systemName: "faceid"), for: .normal)
        faceBtn.tintColor = .systemBlue
        faceBtn.setTitle(" 使用 FaceID / 指纹", for: .normal)
        faceBtn.addTarget(self, action: #selector(faceAuth), for: .touchUpInside)

        hintLabel.text = " "
        hintLabel.textColor = .systemGray2
        hintLabel.font = .systemFont(ofSize: 12)

        let v = UIStackView(arrangedSubviews: [icon, passField, unlockBtn, faceBtn, hintLabel])
        v.axis = .vertical
        v.spacing = 14
        let card = GlassTheme.glassCard(content: v, radius: 24)
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        NSLayoutConstraint.activate([
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.widthAnchor.constraint(equalToConstant: 300),
        ])
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true
        passField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        unlockBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true
    }

    @objc private func enterPass() {
        let p = passField.text ?? ""
        guard p.count >= 4 else { return }
        if check(p, salt: saltReal, hash: hashReal) {
            open(decoy: false)
        } else if check(p, salt: saltDecoy, hash: hashDecoy) {
            open(decoy: true)
        } else {
            hintLabel.text = "密码错误"
            hintLabel.textColor = .systemRed
        }
        passField.text = ""
    }

    private func check(_ pwd: String, salt: Data, hash: String) -> Bool {
        guard !salt.isEmpty, !hash.isEmpty,
              let k = VaultCrypto.deriveKey(password: pwd, salt: salt) else { return false }
        let hex = k.map { String(format: "%02x", $0) }.joined()
        return hex == hash
    }

    @objc private func faceAuth() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            hintLabel.text = "此设备未启用生物识别"
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: "解锁私密相册") { [weak self] ok, _ in
            DispatchQueue.main.async {
                if ok { self?.open(decoy: false) }
            }
        }
    }

    // MARK: - 解锁后
    private func open(decoy: Bool) {
        state = decoy ? .decoy : .unlocked
        if !decoy {
            guard let k = SecureStore.load(key: "vault_key") else { return }
            key = k
            items = store.list()
        } else {
            items = []
        }
        cache.removeAll()
        showGallery()
    }

    private func showGallery() {
        view.subviews.forEach { $0.removeFromSuperview() }

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 6
        layout.minimumLineSpacing = 6
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.dataSource = self
        cv.delegate = self
        cv.register(VaultCell.self, forCellWithReuseIdentifier: "cell")
        cv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cv)
        NSLayoutConstraint.activate([
            cv.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cv.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            cv.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            cv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        gallery = cv

        let add = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addPhotos))
        let lock = UIBarButtonItem(image: UIImage(systemName: "lock"), style: .plain,
                                   target: self, action: #selector(reLock))
        navigationItem.rightBarButtonItems = [add, lock]
        navigationItem.leftBarButtonItem = nil
        // 诱饵进入：相册正常显示（数据为空），不出现任何“诱饵/空相册”提示
        _ = decoyBanner()
    }

    /// 诱饵状态不显示任何标识，让空相册看起来与正常一致
    private func decoyBanner() -> Bool { false }

    @objc func reLock() {
        guard state != .locked else { return } // 幂等：已在锁定态不重建
        state = .locked
        key = nil
        items = []
        cache.removeAll()
        navigationItem.rightBarButtonItems = nil
        showLock()
    }

    @objc private func addPhotos() {
        var cfg = PHPickerConfiguration()
        cfg.filter = .images
        cfg.selectionLimit = 20
        let picker = PHPickerViewController(configuration: cfg)
        picker.delegate = self
        present(picker, animated: true)
    }

    func exportToAlbum(_ item: VaultStore.Item) {
        guard let k = key, let img = store.image(for: item, key: k) else { return }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: img)
        }) { ok, _ in
            DispatchQueue.main.async {
                self.hintLabel.text = ok ? "已导出到系统相册" : "导出失败（相册权限未开启）"
            }
        }
    }
}

extension VaultViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    // iPad / 分屏 / 旋转自适应：按可用宽度动态定列数与格宽
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let w = collectionView.bounds.width
        let spacing: CGFloat = 6
        let columns: CGFloat = w > 900 ? 6 : (w > 600 ? 4 : 3)
        let side = floor((w - spacing * (columns - 1)) / columns)
        return CGSize(width: side, height: side)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        gallery?.collectionViewLayout.invalidateLayout()
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let c = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! VaultCell
        let item = items[indexPath.row]
        if let img = cache[item.id] {
            c.set(img)
        } else if let k = key, let img = store.image(for: item, key: k) {
            cache[item.id] = img
            c.set(img)
        }
        return c
    }
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        let item = items[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let del = UIAction(title: "删除", image: UIImage(systemName: "trash"),
                               attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.store.delete(item)
                self.items = self.store.list()
                self.cache.removeValue(forKey: item.id)
                collectionView.reloadData()
            }
            let ex = UIAction(title: "导出到相册", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.exportToAlbum(item)
            }
            return UIMenu(children: [ex, del])
        }
    }
}

extension VaultViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)
        guard let key = key else { return }
        for r in results {
            r.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
                guard let self = self, let data = data else { return }
                DispatchQueue.main.async {
                    let name = r.itemProvider.suggestedName ?? "photo.png"
                    if self.store.save(imageData: data, name: name, key: key) {
                        self.items = self.store.list()
                        self.gallery?.reloadData()
                    }
                }
            }
        }
    }
}

/// 图格
final class VaultCell: UICollectionViewCell {
    private let img = UIImageView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        img.contentMode = .scaleAspectFill
        img.clipsToBounds = true
        img.layer.cornerRadius = 8
        img.layer.borderWidth = 0.5
        img.layer.borderColor = GlassTheme.stroke.cgColor
        img.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(img)
        NSLayoutConstraint.activate([
            img.topAnchor.constraint(equalTo: contentView.topAnchor),
            img.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            img.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            img.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func set(_ image: UIImage) { img.image = image }
}
