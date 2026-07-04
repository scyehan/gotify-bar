import Carbon.HIToolbox
import SwiftUI

@main
struct GotifyBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar UI is driven manually via NSStatusItem in AppDelegate so the
        // popover can also be toggled by a global hotkey. This scene stays empty.
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = MessageStore()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var hotKey: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApplication.shared.setActivationPolicy(.accessory)

        // Set up notification handling
        NotificationManager.shared.setup()

        setupStatusItem()
        setupPopover()
        setupHotKey()
        observeUnreadCount()

        // Auto-connect if settings are configured
        if store.isConfigured {
            store.connect()
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = icon(for: store.unreadCount)
            button.action = #selector(togglePopover)
            button.target = self
        }
        statusItem = item
    }

    private func icon(for unreadCount: Int) -> NSImage? {
        let name = unreadCount > 0 ? "bell.badge" : "bell"
        return NSImage(systemSymbolName: name, accessibilityDescription: "GotifyBar")
    }

    /// Re-arm observation of `unreadCount` and refresh the menu bar icon whenever it changes.
    private func observeUnreadCount() {
        withObservationTracking {
            _ = store.unreadCount
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.statusItem?.button?.image = self.icon(for: self.store.unreadCount)
                self.observeUnreadCount()
            }
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environment(store)
        )
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: - Global Hotkey

    private func setupHotKey() {
        let manager = HotKeyManager { [weak self] in
            self?.togglePopover()
        }
        // Ctrl+Shift+G
        manager.register(
            keyCode: UInt32(kVK_ANSI_G),
            modifiers: UInt32(controlKey | shiftKey)
        )
        hotKey = manager
    }
}
