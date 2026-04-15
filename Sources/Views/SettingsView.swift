import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(MessageStore.self) private var store
    @Binding var showSettings: Bool

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 16) {
            // Header
            HStack {
                Text("设置")
                    .font(.headline)
                Spacer()
                Button(action: { showSettings = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Server URL
            VStack(alignment: .leading, spacing: 4) {
                Text("服务器地址")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("https://gotify.example.com", text: $store.serverURL)
                    .textFieldStyle(.roundedBorder)
            }

            // Client Token
            VStack(alignment: .leading, spacing: 4) {
                Text("客户端 Token")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                SecureField("Client Token 或 vt://...", text: $store.clientToken)
                    .textFieldStyle(.roundedBorder)
            }

            // VT Binary Path (optional)
            VStack(alignment: .leading, spacing: 4) {
                Text("vt 命令路径 (可选，留空自动查找)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("/opt/homebrew/bin/vt", text: $store.vtBinaryPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            // Status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Divider()

            // Notification settings
            Toggle("新消息声音提醒", isOn: $store.soundEnabled)
                .font(.subheadline)
                .onChange(of: store.soundEnabled) { store.saveSettings() }

            Toggle("验证码弹出通知", isOn: $store.codeAlertEnabled)
                .font(.subheadline)
                .onChange(of: store.codeAlertEnabled) { store.saveSettings() }

            Toggle("显示优先级标签", isOn: $store.priorityBadgeEnabled)
                .font(.subheadline)
                .onChange(of: store.priorityBadgeEnabled) { store.saveSettings() }

            Divider()

            // Connect / Disconnect
            HStack {
                if store.connectionState == .connected || store.connectionState == .connecting {
                    Button("断开连接") {
                        store.disconnect()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("连接") {
                        store.connect()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.isConfigured)
                }
            }

            Spacer()

            // Quit
            Divider()
            Button("退出 GotifyBar") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .font(.caption)
        }
        .padding(16)
    }

    private var statusColor: Color {
        switch store.connectionState {
        case .connected: .green
        case .connecting: .orange
        case .disconnected: .gray
        case .error: .red
        }
    }

    private var statusText: String {
        switch store.connectionState {
        case .connected: "已连接"
        case .connecting: "连接中..."
        case .disconnected: "未连接"
        case .error(let msg): "错误: \(msg)"
        }
    }
}
