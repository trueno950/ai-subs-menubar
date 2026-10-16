import AppKit
import SwiftUI
import Combine
import AISubsCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: StatusPanel?
    private let settingsController = SettingsWindowController()
    private lazy var appState = AppState()
    private var refreshTimer: Timer?
    private var configCancellable: AnyCancellable?

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

        Notifier.requestAuthorizationIfNeeded()
        scheduleRenewals()
        refreshAndDeliverAlerts()
        startRefreshTimer()

        configCancellable = appState.$config.sink { [weak self] _ in
            self?.scheduleRenewals()
            self?.startRefreshTimer()
        }
    }

    private func scheduleRenewals() {
        Notifier.scheduleRenewalNotifications(
            subscriptions: appState.config.subscriptions,
            daysBefore: appState.config.notifyDaysBeforeRenewal)
    }

    private func refreshAndDeliverAlerts() {
        Task { @MainActor in
            await self.appState.refreshSpend()
            for alert in self.appState.alertMessagesAfterRefresh() {
                Notifier.sendBalanceAlert(providerID: alert.providerID,
                                          providerName: alert.providerName,
                                          body: alert.message)
            }
        }
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        let interval = TimeInterval(max(1, appState.config.refreshIntervalMinutes) * 60)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshAndDeliverAlerts()
            }
        }
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
