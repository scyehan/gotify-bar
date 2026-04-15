import AppKit
import SwiftUI

struct MessageRowView: View {
    @Environment(MessageStore.self) private var store
    let message: GotifyMessage
    let onTap: () -> Void

    private var verificationCode: String? {
        guard VerificationCodeDetector.isVerificationCode(
            title: message.title,
            message: message.message
        ) else { return nil }
        return VerificationCodeDetector.extractCode(
            title: message.title,
            message: message.message
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title + timestamp
            HStack {
                Text(message.title.isEmpty ? "无标题" : message.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(message.date.relativeDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Message body — click row to view full
            Text(message.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Verification code badge
            if let code = verificationCode {
                HStack(spacing: 6) {
                    Label(code, systemImage: "lock.shield")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)

                    Button(action: { copyToClipboard(code) }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("复制验证码")

                    Spacer()
                }
                .padding(.top, 2)
            }

            // Priority + delete
            HStack {
                if store.priorityBadgeEnabled {
                    priorityBadge
                }
                Spacer()
                Button(action: { store.deleteMessage(message) }) {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("删除消息")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    @ViewBuilder
    private var priorityBadge: some View {
        if message.priority >= 8 {
            Label("紧急", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        } else if message.priority >= 4 {
            Label("重要", systemImage: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}
