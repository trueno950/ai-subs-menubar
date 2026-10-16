import AppKit
import SwiftUI
import AISubsCore

// MARK: - Application entry

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: StatusPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = StatusPanel(content: PopoverRootView())
        self.panel = panel

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "creditcard",
                                   accessibilityDescription: "AI Subscriptions")
            button.action = #selector(togglePanel(_:))
            button.target = self
        }
        statusItem = item

        panel.placeBelowStatusBarItem(item)
    }

    @objc private func togglePanel(_ sender: Any?) {
        guard let panel, let button = statusItem?.button else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.placeBelowStatusBarItem(statusItem!)
            panel.makeKeyAndOrderFront(nil)
            _ = button // keep reference for positioning
        }
    }
}

// MARK: - Status panel (borderless, non-activating, vibrancy)

/// A borderless NSPanel that appears under the menu bar without stealing focus,
/// styled after system menu extras (Control Center look).
final class StatusPanel: NSPanel {
    private var monitor: Any?

    init(content: some View) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 360, height: 460),
                   styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
                   backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false

        let hosting = NSHostingView(rootView: content)
        contentView = hosting

        startOutsideClickMonitor()
    }

    override var canBecomeKey: Bool { true }

    func placeBelowStatusBarItem(_ item: NSStatusItem) {
        guard let button = item.button, let window = button.window else { return }
        let frame = window.frame
        let width = self.frame.width
        let x = frame.midX - width / 2
        let y = frame.minY - 8
        setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }

    private func startOutsideClickMonitor() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.isVisible else { return }
            let location = NSEvent.mouseLocation
            if !self.frame.contains(location) {
                self.orderOut(nil)
            }
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}

// MARK: - SwiftUI

/// Vibrancy background using the native behind-window blur.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 14
        view.layer?.masksToBounds = true
        view.layer?.cornerCurve = .continuous
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

struct PopoverRootView: View {
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            ScrollView {
                VStack(spacing: 10) {
                    Text("Suscripciones y saldos")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("UI completa llega en T3/T4")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 360, height: 460)
        .background(VisualEffectBackground().ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Label("AI Subs", systemImage: "sparkles")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Text("$0.00")
                .font(.system(.title3, design: .rounded).monospacedDigit().weight(.bold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Bootstrap

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
