import SwiftUI

@main
struct PRNotifierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar is managed by AppDelegate for right-click support
        Settings { EmptyView() }
    }
}
