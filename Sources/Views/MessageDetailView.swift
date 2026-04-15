import AppKit
import SwiftUI

struct MessageDetailView: View {
    let message: GotifyMessage
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Spacer()

                Button(action: copyMessage) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("复制消息内容")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(message.title.isEmpty ? "无标题" : message.title)
                        .font(.headline)

                    Text(message.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text(message.message)
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
            }
        }
    }

    private func copyMessage() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.message, forType: .string)
    }
}
