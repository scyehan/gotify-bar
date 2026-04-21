import AppKit
import Foundation
import Observation

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

@Observable
@MainActor
final class MessageStore {
    var messages: [GotifyMessage] = []
    var connectionState: ConnectionState = .disconnected
    var unreadCount: Int = 0
    var isLoadingMore = false
    var hasMore = true
    var serverURL: String = UserDefaults.standard.string(forKey: "gotifyServerURL") ?? ""
    var clientToken: String = UserDefaults.standard.string(forKey: "gotifyClientToken") ?? ""
    var soundEnabled: Bool = UserDefaults.standard.object(forKey: "gotifySoundEnabled") as? Bool ?? true
    var codeAlertEnabled: Bool = UserDefaults.standard.object(forKey: "gotifyCodeAlertEnabled") as? Bool ?? true
    var priorityBadgeEnabled: Bool = UserDefaults.standard.object(forKey: "gotifyPriorityBadgeEnabled") as? Bool ?? false
    var vtBinaryPath: String = UserDefaults.standard.string(forKey: "gotifyVTBinaryPath") ?? ""

    private var resolvedToken: String = ""
    private var nextSince: UInt?
    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var shouldReconnect = false
    private let pageSize = 20

    var isConfigured: Bool {
        !serverURL.isEmpty && !clientToken.isEmpty
    }

    // MARK: - Public

    func connect() {
        guard isConfigured else {
            connectionState = .error("未配置服务器地址和Token")
            return
        }

        saveSettings()
        shouldReconnect = true
        resetConnection()

        connectionState = .connecting

        // Resolve vt:// token if needed
        do {
            resolvedToken = try Self.resolveVTToken(clientToken, customBinaryPath: vtBinaryPath)
        } catch {
            connectionState = .error("Token解密失败: \(error.localizedDescription)")
            return
        }

        guard let url = buildWebSocketURL() else {
            connectionState = .error("服务器地址无效")
            return
        }

        print("[GotifyBar] Connecting to \(url)")

        let task = URLSession.shared.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        connectionState = .connected

        Task { await fetchHistory() }
        Task { await receiveMessages() }
        startPing()
    }

    func disconnect() {
        shouldReconnect = false
        resetConnection()
        connectionState = .disconnected
    }

    func markAllRead() {
        unreadCount = 0
    }

    func loadMore() {
        guard !isLoadingMore, hasMore else { return }
        Task { await fetchOlderMessages() }
    }

    func refreshHistory() {
        Task { await fetchHistory() }
    }

    func deleteMessage(_ message: GotifyMessage) {
        Task {
            guard let url = buildRESTURL("/message/\(message.id)") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    messages.removeAll { $0.id == message.id }
                }
            } catch {
                print("[GotifyBar] Delete failed: \(error)")
            }
        }
    }

    func deleteAllMessages() {
        Task {
            guard let url = buildRESTURL("/message") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    messages.removeAll()
                    unreadCount = 0
                }
            } catch {
                print("[GotifyBar] Delete all failed: \(error)")
            }
        }
    }

    // MARK: - Private

    func saveSettings() {
        UserDefaults.standard.set(serverURL, forKey: "gotifyServerURL")
        UserDefaults.standard.set(clientToken, forKey: "gotifyClientToken")
        UserDefaults.standard.set(soundEnabled, forKey: "gotifySoundEnabled")
        UserDefaults.standard.set(codeAlertEnabled, forKey: "gotifyCodeAlertEnabled")
        UserDefaults.standard.set(priorityBadgeEnabled, forKey: "gotifyPriorityBadgeEnabled")
        UserDefaults.standard.set(vtBinaryPath, forKey: "gotifyVTBinaryPath")
    }

    private func resetConnection() {
        reconnectTask?.cancel()
        reconnectTask = nil
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    private func fetchHistory() async {
        guard let url = buildRESTURL("/message", queryItems: [
            URLQueryItem(name: "limit", value: "\(pageSize)"),
        ]) else {
            print("[GotifyBar] Failed to build REST URL")
            return
        }

        print("[GotifyBar] Fetching history from \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let http = response as? HTTPURLResponse {
                print("[GotifyBar] History response: \(http.statusCode)")
                if http.statusCode == 401 {
                    connectionState = .error("Token无效")
                    disconnect()
                    return
                }
            }

            let result = try JSONDecoder.gotify.decode(MessageListResponse.self, from: data)
            messages = result.messages.sorted { $0.date > $1.date }
            nextSince = result.paging.since
            hasMore = result.paging.size >= pageSize
            print("[GotifyBar] Loaded \(messages.count) messages, hasMore=\(hasMore)")
        } catch {
            print("[GotifyBar] Fetch history failed: \(error)")
        }
    }

    private func fetchOlderMessages() async {
        guard let since = nextSince else {
            hasMore = false
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        guard let url = buildRESTURL("/message", queryItems: [
            URLQueryItem(name: "limit", value: "\(pageSize)"),
            URLQueryItem(name: "since", value: "\(since)"),
        ]) else { return }

        print("[GotifyBar] Loading more since=\(since)")

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder.gotify.decode(MessageListResponse.self, from: data)
            let older = result.messages.sorted { $0.date > $1.date }
            let existingIDs = Set(messages.map(\.id))
            let newMessages = older.filter { !existingIDs.contains($0.id) }
            messages.append(contentsOf: newMessages)
            nextSince = result.paging.since
            hasMore = result.paging.size >= pageSize
            print("[GotifyBar] Loaded \(newMessages.count) more, total=\(messages.count), hasMore=\(hasMore)")
        } catch {
            print("[GotifyBar] Load more failed: \(error)")
        }
    }

    private func receiveMessages() async {
        guard let task = webSocketTask else { return }

        do {
            while task.state == .running {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    guard let data = text.data(using: .utf8) else { continue }
                    if let msg = try? JSONDecoder.gotify.decode(GotifyMessage.self, from: data) {
                        handleNewMessage(msg)
                    }
                case .data(let data):
                    if let msg = try? JSONDecoder.gotify.decode(GotifyMessage.self, from: data) {
                        handleNewMessage(msg)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            if shouldReconnect {
                connectionState = .disconnected
                scheduleReconnect()
            }
        }
    }

    private func handleNewMessage(_ message: GotifyMessage) {
        messages.insert(message, at: 0)
        unreadCount += 1

        let isCode = VerificationCodeDetector.isVerificationCode(
            title: message.title, message: message.message
        )
        let code = VerificationCodeDetector.extractCode(
            title: message.title, message: message.message
        )
        print("[GotifyBar] New message: title=\(message.title) isCode=\(isCode) code=\(code ?? "nil") codeAlertEnabled=\(codeAlertEnabled)")

        if isCode, codeAlertEnabled, let code, !code.isEmpty {
            NotificationManager.shared.postVerificationCode(
                title: message.title,
                message: message.message,
                code: code
            )
        } else if soundEnabled {
            NSSound(named: "Glass")?.play()
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, shouldReconnect else { return }
            print("[GotifyBar] Reconnecting...")
            connect()
        }
    }

    private func startPing() {
        pingTask?.cancel()
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                webSocketTask?.sendPing { error in
                    if let error = error {
                        print("[GotifyBar] Ping failed: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - VT Token Resolution

    private nonisolated static let vtSearchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
    ]

    /// Resolve a `vt://` URI to plaintext via `vt read` or `vt-yubi read`, or return the token as-is.
    /// Runs through user's login shell so `.zshrc`/`.bash_profile` (with `VT_AUTH`, PATH, etc.) is sourced.
    /// If `customBinaryPath` is non-empty, use it directly; otherwise rely on shell PATH (or auto-discover as fallback).
    private nonisolated static func resolveVTToken(_ token: String, customBinaryPath: String) throws -> String {
        guard token.hasPrefix("vt://") else { return token }

        let binary: String
        let trimmed = customBinaryPath.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            guard FileManager.default.isExecutableFile(atPath: trimmed) else {
                throw VTError.customBinaryInvalid(trimmed)
            }
            binary = trimmed
        } else if let found = findVTBinary() {
            binary = found
        } else {
            // Let the login shell resolve via PATH
            binary = "vt"
        }

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let command = "\(shellQuote(binary)) read \(shellQuote(token))"

        // -i (interactive) + -l (login) ensures .zshrc / .zprofile / .zshenv are all sourced
        // so VT_AUTH, VT_ADDR, PATH from user's shell config are available.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-i", "-l", "-c", command]

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errOutput = String(data: errData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0, !output.isEmpty else {
            let msg = errOutput.isEmpty ? output : errOutput
            throw VTError.decryptionFailed(msg)
        }

        return output
    }

    private nonisolated static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Search for `vt` first, then `vt-yubi` in standard locations.
    private nonisolated static func findVTBinary() -> String? {
        let fm = FileManager.default
        for name in ["vt", "vt-yubi"] {
            for dir in vtSearchPaths {
                let path = "\(dir)/\(name)"
                if fm.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }
        return nil
    }

    enum VTError: LocalizedError {
        case binaryNotFound
        case customBinaryInvalid(String)
        case decryptionFailed(String)

        var errorDescription: String? {
            switch self {
            case .binaryNotFound:
                return "未找到 vt 或 vt-yubi，请在设置中指定路径"
            case .customBinaryInvalid(let path):
                return "指定的 vt 路径无效: \(path)"
            case .decryptionFailed(let msg):
                return msg.isEmpty ? "vt read failed" : msg
            }
        }
    }

    // MARK: - URL Building

    private func buildWebSocketURL() -> URL? {
        guard var components = URLComponents(string: serverURL) else { return nil }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = basePath.isEmpty ? "/stream" : "/\(basePath)/stream"
        components.queryItems = [URLQueryItem(name: "token", value: resolvedToken)]
        return components.url
    }

    private func buildRESTURL(_ endpoint: String, queryItems: [URLQueryItem] = []) -> URL? {
        guard var components = URLComponents(string: serverURL) else { return nil }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let ep = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = basePath.isEmpty ? "/\(ep)" : "/\(basePath)/\(ep)"
        var items = queryItems
        items.append(URLQueryItem(name: "token", value: resolvedToken))
        components.queryItems = items
        return components.url
    }
}
