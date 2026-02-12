import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private let viewModel: PRViewModel
    private let settings: AppSettings

    init(viewModel: PRViewModel, settings: AppSettings) {
        self.viewModel = viewModel
        self.settings = settings
    }

    func showSettings() {
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView()
                .environment(viewModel)
                .environment(settings)
        )

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newPanel.title = "PR Notifier Settings"
        newPanel.contentViewController = hostingController
        newPanel.isFloatingPanel = true
        newPanel.becomesKeyOnlyIfNeeded = false
        newPanel.isReleasedWhenClosed = false
        newPanel.delegate = self
        newPanel.setFrameAutosaveName("SettingsPanel")
        newPanel.center()

        self.panel = newPanel
        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        // No-op: panel is hidden, not destroyed, so SwiftUI state is preserved.
    }
}
