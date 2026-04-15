# GotifyBar

macOS 菜单栏 Gotify 客户端。实时接收 Gotify 服务器消息，对验证码短信主动弹出通知。

## 功能

- 菜单栏托盘图标，无 Dock 图标，纯后台常驻
- WebSocket 实时接收消息，自动重连（5s 退避）+ 30s ping 保活
- REST API 拉取历史消息，滚动到底部自动加载更多（每次 20 条）
- 验证码短信识别（中英文关键词 + 4-8 位数字正则）
- 验证码主动弹出系统通知，**点击通知自动复制验证码到剪贴板**
- 普通新消息播放 Glass 提示音
- 点击消息行查看完整内容（支持文字选中、复制）
- 单条/批量删除、标记已读
- 支持 [`vt` / `vt-yubi`](https://github.com/scyehan/vt-yubi) 加密 Token，运行时通过 YubiKey 解密

## 配置项

设置面板（点击菜单栏图标 → 齿轮）：

| 项 | 说明 | 默认 |
|---|---|---|
| 服务器地址 | Gotify 服务器 URL | — |
| 客户端 Token | Client Token 或 `vt://...` URI | — |
| vt 命令路径 | 自定义 vt 二进制路径，留空自动查找 | — |
| 新消息声音提醒 | 普通消息播放 Glass 音效 | ✅ |
| 验证码弹出通知 | 验证码消息弹系统通知 | ✅ |
| 显示优先级标签 | 根据 priority 显示「紧急」「重要」 | ❌ |

## 系统要求

- macOS 14+
- Swift 5.10+ / Xcode 15+
- [`terminal-notifier`](https://github.com/julienXX/terminal-notifier)（验证码通知用）：
  ```bash
  brew install terminal-notifier
  ```
- 可选：[`vt` 或 `vt-yubi`](https://github.com/scyehan/vt-yubi)（仅当使用 `vt://` Token 时）

## 构建与运行

提供 `Makefile` 一键打包：

```bash
make build      # swift build，仅编译可执行文件
make bundle     # 编译 + 打包成 .app（含 Info.plist、ATS 配置）
make run        # bundle 之后用 open 启动
make install    # 安装到 /Applications
make clean      # 清理产物
```

### 直接从源码运行

```bash
make bundle
.build/debug/GotifyBar.app/Contents/MacOS/GotifyBar
```

直接运行可执行文件可以在终端实时看到日志，便于调试。

### 使用 Xcode

```bash
open Package.swift
```

Xcode 会识别 SwiftPM 包，按 `Cmd+R` 即可运行。

## vt:// Token 支持

[vt-yubi](https://github.com/scyehan/vt-yubi) 是一个用 YubiKey 加密本地密钥的 KMS。如果 Client Token 配置为 `vt://...` 形式，启动连接时会自动调用 `vt read <uri>` 解密。

**关键点**：vt 通常需要 `VT_AUTH` 环境变量，而 GUI 程序通过 Finder/`open` 启动时**不会**加载 `.zshrc`。GotifyBar 通过 `$SHELL -ilc` 启动登录 + 交互式 shell，确保 `.zshrc` 中的 `VT_AUTH`、`VT_ADDR`、`PATH` 等都被加载。

vt 二进制查找顺序：
1. 设置中的「vt 命令路径」（如已配置）
2. `/opt/homebrew/bin/{vt,vt-yubi}`
3. `/usr/local/bin/{vt,vt-yubi}`
4. `/usr/bin/{vt,vt-yubi}`
5. 否则交给登录 shell 通过 `PATH` 解析

## 验证码识别

正则规则参考 [`gotify-notify`](https://github.com/.../gotify-notify) Go 版本：

- **关键词匹配**（标题 + 内容）：`验证码`、`动态密码`、`短信码`、`密码`、`口令`、`verification`、`verify code`、`otp`、`pin码`、`security code`、`confirmation code`、`captcha`
- **正则匹配**：`(?i)(验证码|verification|verify|code|OTP|PIN|...)[：:\s]*(\d{4,8})`
- **回退**：`\b(\d{4,8})\b`

匹配成功 → 弹通知（点击复制到剪贴板）。匹配失败 → 仅播放 Glass 音效。

## 项目结构

```
gotify-bar/
├── Package.swift              # SwiftPM 配置
├── Makefile                   # 构建/打包/安装
├── README.md
└── Sources/
    ├── GotifyBarApp.swift     # @main + AppDelegate
    ├── Models/
    │   └── GotifyMessage.swift
    ├── Services/
    │   ├── VerificationCodeDetector.swift
    │   └── NotificationManager.swift  # terminal-notifier 包装
    ├── Stores/
    │   └── MessageStore.swift  # WebSocket + REST + @Observable
    └── Views/
        ├── ContentView.swift
        ├── MessageListView.swift
        ├── MessageRowView.swift
        ├── MessageDetailView.swift
        └── SettingsView.swift
```

## 故障排查

**菜单栏没有图标**：必须用 `make bundle` 后启动 .app，直接 `swift run` 因没有 Info.plist 会崩溃。

**通知不弹出**：检查是否安装了 `terminal-notifier`（`which terminal-notifier`）。

**vt:// 解密失败**：
- 终端运行 `vt read vt://...` 看是否能解密
- 双击启动失败但 `open` 启动成功 → 通常是 `VT_AUTH` 不在 `.zshrc` 而在某些只对终端生效的位置
- 在设置中明确指定「vt 命令路径」

**HTTP 服务器连不上**：Makefile 已自动配置 ATS `NSAllowsArbitraryLoads = true`。如果改了配置仍连不上，删掉 `.build/debug/GotifyBar.app` 后重新 `make bundle`。

**查看日志**：从终端运行
```bash
.build/debug/GotifyBar.app/Contents/MacOS/GotifyBar
```
所有 `print` 输出会直接打到终端。
