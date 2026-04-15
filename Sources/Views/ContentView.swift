import SwiftUI

struct ContentView: View {
    @Environment(MessageStore.self) private var store
    @State private var showSettings = false
    @State private var selectedMessage: GotifyMessage?

    var body: some View {
        Group {
            if showSettings {
                SettingsView(showSettings: $showSettings)
            } else if let msg = selectedMessage {
                MessageDetailView(message: msg) {
                    selectedMessage = nil
                }
            } else {
                MessageListView(
                    showSettings: $showSettings,
                    onSelectMessage: { selectedMessage = $0 }
                )
            }
        }
        .frame(width: 360, height: 480)
    }
}
