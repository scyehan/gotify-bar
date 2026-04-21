import SwiftUI

@MainActor
struct MessageListView: View {
    @Environment(MessageStore.self) private var store
    @Binding var showSettings: Bool
    let onSelectMessage: (GotifyMessage) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.messages.isEmpty {
                emptyState
            } else {
                messageList
            }

            if !store.messages.isEmpty {
                Divider()
                footer
            }
        }
        .onAppear {
            if store.messages.isEmpty, store.connectionState == .connected {
                store.refreshHistory()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if store.connectionState != .connected, store.isConfigured {
                Button(action: { store.connect() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("重新连接")
            }

            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("暂无消息")
                .foregroundStyle(.secondary)
            if !store.isConfigured {
                Button("配置服务器") {
                    showSettings = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            Spacer()
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.messages) { message in
                    MessageRowView(message: message) {
                        onSelectMessage(message)
                    }
                    Divider()
                        .padding(.horizontal, 12)
                }

                if store.hasMore {
                    loadMoreTrigger
                }
            }
        }
    }

    private var loadMoreTrigger: some View {
        Group {
            if store.isLoadingMore {
                ProgressView()
                    .controlSize(.small)
                    .padding(12)
            } else {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        store.loadMore()
                    }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("全部已读") {
                store.markAllRead()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.blue)

            Spacer()

            Button("清空全部") {
                store.deleteAllMessages()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Status

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
