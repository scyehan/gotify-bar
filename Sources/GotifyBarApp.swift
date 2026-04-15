import SwiftUI

@main
struct GotifyBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environment(appDelegate.store)
        } label: {
            Image(systemName: appDelegate.store.unreadCount > 0 ? "bell.badge" : "bell")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let store = MessageStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApplication.shared.setActivationPolicy(.accessory)

        // Set up notification handling
        NotificationManager.shared.setup()

        // Auto-connect if settings are configured
        if store.isConfigured {
            store.connect()
        }
    }
}
