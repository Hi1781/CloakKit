import UIKit
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

/// 对话界面：文字 / 图片 / 文件 / 语音 收发与本地展示
final class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,
                                 UITextFieldDelegate, UIDocumentPickerDelegate, PHPickerViewControllerDelegate,
                                 AVAudioRecorderDelegate, AVAudioPlayerDelegate {

    var peer: ChatPeer!
    private let table = UITableView(frame: .zero, style: .plain)
    private let input = UITextField()
    private var inputBottom: NSLayoutConstraint?

    private let store = ChatStore.shared
    private var msgs: [ChatMessage] { store.messages[peer.id] ?? [] }

    // 附件
    private let attachBtn = UIButton(type: .system)
    private let sendBtn = UIButton(type: .system)
    private let fireBtn = UIButton(type: .system)
    private var burnOn = false
    private var recorder: AVAudioRecorder?
    private var isRecording = false
    private var audioPlayer: AVAudioPlayer?

    // 阅后即焚销毁任务去重
    private var burning = Set<String>()

    private let rowHeight: CGFloat = 56

    override func viewDidLoad() {
        super.viewDidLoad()
        title = peer.name
        GlassTheme.installScene(on: view)
        table.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = rowHeight
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)
        buildInputBar()
        NotificationCenter.default.addObserver(self, selector: #selector(kb),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        table.reloadData()
        scrollBottom(animated: false)
        scheduleBurns()
    }

    /// 阅后即焚：对方发来的焚消息被“读”（展示）后，N 秒后本地销毁（含持久化）
    private func scheduleBurns() {
        let current = msgs
        for m in current {
            guard !m.fromMe, let sec = m.burnAfter, sec > 0, !burning.contains(m.id) else { continue }
            burning.insert(m.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(sec)) { [weak self] in
                guard let self = self else { return }
                self.store.removeMessage(id: m.id, from: self.peer.id)
                self.burning.remove(m.id)
                self.table.reloadData()
            }
        }
    }

    private func buildInputBar() {
        input.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        input.layer.borderWidth = 0.5
        input.layer.borderColor = GlassTheme.stroke.cgColor
        input.textColor = .white
        input.placeholder = "输入消息"
        input.delegate = self
        input.returnKeyType = .send
        input.layer.cornerRadius = 18
        input.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 36))
        input.leftViewMode = .always

        attachBtn.setImage(UIImage(systemName: "plus.circle"), for: .normal)
        attachBtn.tintColor = GlassTheme.tint
        attachBtn.addTarget(self, action: #selector(attachTap), for: .touchUpInside)

        // 阅后即焚开关：点亮后下一消息读后 N 秒销毁、本地不落地
        fireBtn.setImage(UIImage(systemName: "flame"), for: .normal)
        fireBtn.tintColor = GlassTheme.tint
        fireBtn.addTarget(self, action: #selector(toggleBurn), for: .touchUpInside)
        fireBtn.widthAnchor.constraint(equalToConstant: 30).isActive = true

        sendBtn.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendBtn.tintColor = GlassTheme.tint
        sendBtn.addTarget(self, action: #selector(sendMsg), for: .touchUpInside)

        input.rightView = sendBtn
        input.rightViewMode = .always

        let bar = UIStackView(arrangedSubviews: [attachBtn, fireBtn, input])
        bar.axis = .horizontal
        bar.spacing = 8
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            table.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -6),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            bar.heightAnchor.constraint(equalToConstant: 40),
            attachBtn.widthAnchor.constraint(equalToConstant: 34),
        ])
        inputBottom = bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        inputBottom?.isActive = true
    }

    @objc private func toggleBurn() {
        burnOn.toggle()
        fireBtn.setImage(UIImage(systemName: burnOn ? "flame.fill" : "flame"), for: .normal)
        fireBtn.tintColor = burnOn ? .systemRed : GlassTheme.tint
    }

    @objc private func kb(_ n: Notification) {
        guard let f = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let h = max(0, view.bounds.height - f.minY)
        inputBottom?.constant = -8 - h
        view.layoutIfNeeded()
        scrollBottom(animated: true)
    }

    // MARK: - 附件
    @objc private func attachTap() {
        if isRecording { stopRecordAndSend(); return }
        let a = UIAlertController(title: "发送", message: nil, preferredStyle: .actionSheet)
        a.addAction(UIAlertAction(title: "照片", style: .default) { [weak self] _ in self?.pickPhoto() })
        a.addAction(UIAlertAction(title: "文件", style: .default) { [weak self] _ in self?.pickFile() })
        a.addAction(UIAlertAction(title: isRecording ? "停止并发送语音" : "语音", style: .default) { [weak self] _ in self?.toggleRecord() })
        a.addAction(UIAlertAction(title: "取消", style: .cancel))
        a.popoverPresentationController?.sourceView = attachBtn
        present(a, animated: true)
    }

    private func pickPhoto() {
        var cfg = PHPickerConfiguration()
        cfg.filter = .images
        cfg.selectionLimit = 1
        let p = PHPickerViewController(configuration: cfg)
        p.delegate = self
        present(p, animated: true)
    }
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)
        guard let r = results.first else { return }
        r.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            let name = (r.itemProvider.suggestedName ?? "photo") + ".png"
            let ext = (name as NSString).pathExtension
            guard let url = self.store.copyMedia(url(for: data, name: name), ext: ext) else { return }
            DispatchQueue.main.async {
                self.append(kind: "image", fileName: url.lastPathComponent)
            }
        }
    }
    private func url(for data: Data, name: String) -> URL {
        let t = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: t)
        return t
    }

    private func pickFile() {
        let p = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        p.delegate = self
        p.allowsMultipleSelection = false
        present(p, animated: true)
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let ext = url.pathExtension.isEmpty ? "file" : url.pathExtension
        guard let dest = store.copyMedia(url, ext: ext) else { return }
        append(kind: "file", fileName: dest.lastPathComponent, text: url.lastPathComponent)
    }

    // MARK: - 语音
    private func toggleRecord() {
        if isRecording { stopRecordAndSend(); return }
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] ok in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard ok else {
                    let a = UIAlertController(title: "无法录音", message: "请在系统设置中允许麦克风权限", preferredStyle: .alert)
                    a.addAction(UIAlertAction(title: "好", style: .default))
                    self.present(a, animated: true)
                    return
                }
                self.startRecord()
            }
        }
    }
    private func startRecord() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("rec.m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.record()
            isRecording = true
            attachBtn.setImage(UIImage(systemName: "stop.circle.fill"), for: .normal)
            attachBtn.tintColor = .systemRed
        } catch { }
    }
    private func stopRecordAndSend() {
        recorder?.stop()
        isRecording = false
        attachBtn.setImage(UIImage(systemName: "plus.circle"), for: .normal)
        attachBtn.tintColor = GlassTheme.tint
    }
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let src = recorder.url
        let dur = Int(recorder.currentTime)
        guard let dest = store.copyMedia(src, ext: "m4a") else { return }
        DispatchQueue.main.async {
            self.append(kind: "audio", fileName: dest.lastPathComponent, text: "\(dur)")
        }
    }

    // MARK: - 发送
    private func append(kind: String, fileName: String = "", text: String = "") {
        var m = ChatMessage(id: UUID().uuidString, peerId: peer.id, kind: kind,
                            text: text, fileName: fileName, fromMe: true,
                            time: Self.now(), burnAfter: nil)
        if burnOn {
            m.burnAfter = 10          // 阅后即焚：读后 10 秒销毁
            burnOn = false
            fireBtn.setImage(UIImage(systemName: "flame"), for: .normal)
            fireBtn.tintColor = GlassTheme.tint
        }
        store.addMessage(m)
        input.text = ""
        table.reloadData()
        scrollBottom(animated: true)
    }
    @objc private func sendMsg() {
        let t = input.text ?? ""
        guard !t.isEmpty else { return }
        append(kind: "text", text: t)
    }
    func textFieldShouldReturn(_ f: UITextField) -> Bool { sendMsg(); return true }

    private static func now() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: Date())
    }
    private func scrollBottom(animated: Bool) {
        let n = msgs.count
        guard n > 0 else { return }
        table.scrollToRow(at: IndexPath(row: n - 1, section: 0), at: .bottom, animated: animated)
    }

    // MARK: - Table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { max(msgs.count, 1) }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "c")
            ?? MessageCell(style: .default, reuseIdentifier: "c")
        guard let c = cell as? MessageCell else { return cell }
        if indexPath.row >= msgs.count {
            c.configurePlaceholder()
            return c
        }
        c.configure(msgs[indexPath.row], store: store)
        return c
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < msgs.count else { return }
        let m = msgs[indexPath.row]
        if m.kind == "file" {
            let url = store.mediaDir.appendingPathComponent(m.fileName)
            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            av.popoverPresentationController?.sourceView = table
            present(av, animated: true)
        } else if m.kind == "audio" {
            playAudio(m)
        }
    }

    private func playAudio(_ m: ChatMessage) {
        let url = store.mediaDir.appendingPathComponent(m.fileName)
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } catch { }
    }
}

/// 消息气泡（text / image / file / audio）
final class MessageCell: UITableViewCell {
    private let bubble = UIView()
    private let label = UILabel()
    private let thumb = UIImageView()
    private let fileIcon = UIImageView()

    // 存储式对齐约束（避免反复激活累积冲突）
    private var leadPin: NSLayoutConstraint!
    private var trailPin: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.layer.cornerRadius = 14
        contentView.addSubview(bubble)

        label.font = .systemFont(ofSize: 15)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(label)

        thumb.contentMode = .scaleAspectFill
        thumb.clipsToBounds = true
        thumb.layer.cornerRadius = 10
        thumb.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(thumb)

        fileIcon.contentMode = .scaleAspectFit
        fileIcon.tintColor = .white
        fileIcon.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(fileIcon)

        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            bubble.widthAnchor.constraint(lessThanOrEqualToConstant: 260),
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -10),
            thumb.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 4),
            thumb.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -4),
            thumb.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 4),
            thumb.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -4),
            thumb.widthAnchor.constraint(equalToConstant: 140),
            thumb.heightAnchor.constraint(equalToConstant: 140),
            fileIcon.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            fileIcon.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            fileIcon.widthAnchor.constraint(equalToConstant: 22),
            fileIcon.heightAnchor.constraint(equalToConstant: 22),
        ])

        leadPin = bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10)
        trailPin = bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10)
        NSLayoutConstraint.activate([
            bubble.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 50),
            bubble.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -50),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configurePlaceholder() {
        label.text = "「端到端加密 · 消息仅本地留存，无服务器」"
        label.textColor = .systemGray2
        label.textAlignment = .center
        thumb.isHidden = true; fileIcon.isHidden = true
        bubble.backgroundColor = .clear
        leadPin.constant = 80; trailPin.constant = -80
        leadPin.isActive = true; trailPin.isActive = true
    }

    func configure(_ m: ChatMessage, store: ChatStore) {
        let right = m.fromMe
        bubble.backgroundColor = right ? UIColor.systemBlue.withAlphaComponent(0.35) : UIColor.white.withAlphaComponent(0.12)
        leadPin.isActive = !right
        trailPin.isActive = right
        leadPin.constant = 50
        trailPin.constant = -50

        switch m.kind {
        case "system":
            // 系统告警：居中灰字、无气泡
            label.isHidden = false; thumb.isHidden = true; fileIcon.isHidden = true
            label.text = m.text
            label.textColor = .systemGray2
            label.textAlignment = .center
            bubble.backgroundColor = .clear
            leadPin.constant = 60; trailPin.constant = -60
            leadPin.isActive = true; trailPin.isActive = true
            return
        case "image":
            label.isHidden = true
            thumb.isHidden = false; fileIcon.isHidden = true
            let url = store.mediaDir.appendingPathComponent(m.fileName)
            thumb.image = UIImage(contentsOfFile: url.path)
        case "file":
            label.isHidden = false; thumb.isHidden = true; fileIcon.isHidden = false
            fileIcon.image = UIImage(systemName: "doc.fill")
            label.text = "[附件] " + m.text
        case "audio":
            label.isHidden = false; thumb.isHidden = true; fileIcon.isHidden = false
            fileIcon.image = UIImage(systemName: "play.fill")
            label.text = "语音 \(m.text)s · 点击播放"
        default:
            label.isHidden = false; thumb.isHidden = true; fileIcon.isHidden = true
            label.text = m.text
        }
        // 阅后即焚标记
        if let b = m.burnAfter, b > 0, m.kind != "system" {
            label.text = (label.text ?? "") + "  [\(b)s 后销毁]"
        }
        label.textColor = .white
        label.textAlignment = right ? .right : .left
    }
}
