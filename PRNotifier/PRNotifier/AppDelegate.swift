import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let viewModel = PRViewModel(settings: AppSettings())

    private lazy var settingsWindowController = SettingsWindowController(
        viewModel: viewModel,
        settings: viewModel.settings
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create popover with SwiftUI content
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView(onOpenSettings: { [weak self] in
                self?.openSettings()
            })
            .environment(viewModel)
            .environment(viewModel.settings)
        )

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Start observing viewModel for title updates
        observeMenuBarTitle()
        observeConfigured()

        // Auto-open settings on first launch if not configured
        if !viewModel.settings.isConfigured && !viewModel.settings.devShowSamplePRs {
            openSettings()
        }
    }

    private func openSettings() {
        popover.performClose(nil)
        settingsWindowController.showSettings()
    }

    private func observeConfigured() {
        withObservationTracking {
            _ = viewModel.settings.isConfigured
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.viewModel.settings.isConfigured {
                    self.openSettings()
                }
                self.observeConfigured()
            }
        }
    }

    private func observeMenuBarTitle() {
        withObservationTracking {
            statusItem.button?.title = viewModel.menuBarTitle
        } onChange: {
            Task { @MainActor [weak self] in
                self?.observeMenuBarTitle()
            }
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let checkNowItem = NSMenuItem(
            title: "Check Now",
            action: #selector(checkNowMenuAction),
            keyEquivalent: "r"
        )
        checkNowItem.target = self
        menu.addItem(checkNowItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(settingsMenuAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        menu.addItem(
            NSMenuItem(
                title: "Quit PR Notifier",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func checkNowMenuAction() {
        Task { await viewModel.checkNow() }
    }

    @objc private func settingsMenuAction() {
        openSettings()
    }
}
