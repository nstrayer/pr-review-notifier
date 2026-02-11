import SwiftUI

@main
struct PRNotifierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar is managed by AppDelegate for right-click support.
        // SwiftUI requires at least one Scene. With LSUIElement=true there's
        // no app menu bar, so this Settings scene is never reachable.
        Settings { EmptyView() }
    }
}
