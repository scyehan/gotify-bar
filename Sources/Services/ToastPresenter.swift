import AppKit
import SwiftUI

/// Shows lightweight toast notifications in the top-right corner of the screen.
/// Each toast fades in, stays visible for `displayDuration`, then fades out and is removed.
/// Multiple toasts stack vertically and reflow as older ones disappear.
@MainActor
final class ToastPresenter {
    static let shared = ToastPresenter()

    private var toasts: [ToastWindow] = []
    private let width: CGFloat = 340
    private let spacing: CGFloat = 8
    private let topMargin: CGFloat = 8
    private let rightMargin: CGFloat = 12
    private let maxVisible = 5

    private init() {}

    func show(title: String, message: String) {
        let toast = ToastWindow(title: title, body: message, width: width) { [weak self] window in
            self?.remove(window)
        }
        toasts.append(toast)

        // Cap the number of on-screen toasts by evicting the oldest.
        if toasts.count > maxVisible {
            let oldest = toasts.removeFirst()
            oldest.dismiss()
        }

        layout(animated: false)
        toast.present()
    }

    private func remove(_ window: ToastWindow) {
        guard let index = toasts.firstIndex(where: { $0 === window }) else { return }
        toasts.remove(at: index)
        layout(animated: true)
    }

    private func layout(animated: Bool) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        var y = visible.maxY - topMargin

        for toast in toasts {
            let size = toast.frame.size
            y -= size.height
            let origin = NSPoint(x: visible.maxX - rightMargin - size.width, y: y)
            if animated {
                toast.animator().setFrameOrigin(origin)
            } else {
                toast.setFrameOrigin(origin)
            }
            y -= spacing
        }
    }
}

/// A borderless, non-activating panel that renders a single toast and manages its own lifecycle.
@MainActor
final class ToastWindow: NSPanel {
    private let displayDuration: Duration = .seconds(5)
    private var dismissTask: Task<Void, Never>?
    private let onDismiss: (ToastWindow) -> Void
    private var isDismissing = false

    init(title: String, body: String, width: CGFloat, onDismiss: @escaping (ToastWindow) -> Void) {
        self.onDismiss = onDismiss

        let content = ToastContentView(title: title, message: body)
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: 1)
        let fittingHeight = max(hosting.fittingSize.height, 44)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: width, height: fittingHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
        alphaValue = 0

        hosting.frame = NSRect(x: 0, y: 0, width: width, height: fittingHeight)
        contentView = hosting
    }

    // Borderless panels can't become key by default; we don't need focus, just visibility.
    override var canBecomeKey: Bool { false }

    func present() {
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            animator().alphaValue = 1
        }
        scheduleDismiss()
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: self?.displayDuration ?? .seconds(5))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        dismissTask?.cancel()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.orderOut(nil)
                self.onDismiss(self)
            }
        }
    }

    // Click anywhere on the toast to dismiss it immediately.
    override func mouseDown(with event: NSEvent) {
        dismiss()
    }
}

private struct ToastContentView: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell.fill")
                .font(.system(size: 16))
                .foregroundStyle(.tint)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }
}
