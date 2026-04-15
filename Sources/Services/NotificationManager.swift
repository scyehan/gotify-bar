import AppKit
import Foundation

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func setup() {}

    func postVerificationCode(title: String, message: String, code: String) {
        print("[GotifyBar] Posting notification: code=\(code)")

        let displayTitle = title.isEmpty ? "验证码" : title
        let body = "验证码: \(code)\n点击复制到剪贴板"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/terminal-notifier")
        process.arguments = [
            "-title", displayTitle,
            "-message", body,
            "-sound", "Glass",
            "-group", "gotifybar-code",
            "-execute", "printf '%s' '\(code)' | pbcopy",
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            print("[GotifyBar] Notification failed: \(error)")
        }
    }
}
