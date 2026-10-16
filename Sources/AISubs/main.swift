import AppKit
import SwiftUI
import AISubsCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: StatusPanel?
    private let settingsController = SettingsWindowController()
    private lazy var appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = StatusPanel(content: PopoverRootView(
            appState: appState,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }
        ))
        self.panel = panel

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "creditcard",
                                   accessibilityDescription: "AI Subscriptions")
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        panel.placeBelowStatusBarItem(item)
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent, let button = statusItem?.button else {
            togglePanel()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu(for: button)
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        guard let panel, let statusItem else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.placeBelowStatusBarItem(statusItem)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    private func showContextMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()
        let settingsItem = menu.addItem(withTitle: "Settings…",
                                        action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit AI Subs",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openSettings() {
        panel?.orderOut(nil)
        settingsController.show(appState: appState)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
