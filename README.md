# CloakKit 🔐

iOS Privacy Toolkit — **sideload only**（不上架，仅供个人侧载使用）。

> ⚠️ This app is for **educational / personal use only**. Not for App Store.
> Requires sideload (SideStore / TrollStore). No real guarantee against jailbroken
> devices or physical photo capture.

## Features

- 🔒 **应用锁 / 模块锁**：主密码 + 二级密码 + FaceID/指纹；**胁迫密码 = 一键清空全部数据并闪退**（销毁模式）
- 🖼️ **加密私密相册**：AES-256 加密存储、诱饵密码空相册
- 💬 **私密通讯**：Peer ID / 邀请码、群聊、文字/照片/文件/语音、**阅后即焚**（读后定时销毁、本地不落地）
- 📤 **局域网高速文件互传**（MultipeerConnectivity 自动发现）
- 📊 **隐私审计**：解析 iOS「App 隐私报告」NDJSON / JSON
- 🧅 **Tor / SOCKS5 代理引擎**：真实 SOCKS5 握手 / 节点连通性探测
- 🛡️ **防截屏 / 防录屏**：录屏/投屏实时检测全屏屏蔽、后台缩略图模糊、**截屏/录屏自动上报对端安全告警**
- 🌐 **隐私浏览器**（应用内）
- 📈 性能监控、设备信息、8 大 Tab、iPhone + iPad / iOS16+

## Build

Cross-compiled on Linux (`swiftc` + iPhoneOS16.4 SDK + ldid 伪签名 → raw unsigned IPA)。

```bash
SWIFT_TOOLCHAIN=... IOS_SDK=... ./build.sh
python3 verify.py   # 深度校验 Mach-O / CodeDirectory / 签名 / plist / IPA
```

## Releases

每版本 IPA 见右侧 **Releases**（raw unsigned，侧载安装）。

## License

[MIT](LICENSE)
