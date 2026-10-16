import AppKit
import SwiftUI
import AISubsCore

/// Sheet presentation state without @State macros.
@MainActor
final class SheetModel: ObservableObject {
    struct Session: Identifiable {
        let id = UUID()
        let mode: SubscriptionEditor.Mode
        let form: EditorForm
    }

    @Published var session: Session?

    func present(_ mode: SubscriptionEditor.Mode) {
        switch mode {
        case .add:
            session = Session(mode: .add, form: EditorForm())
        case .edit(let subscription):
            session = Session(mode: .edit(subscription),
                              form: .forSubscription(subscription))
        }
    }

    func dismiss() {
        session = nil
    }
}

/// Owns the regular settings window (activating, with a standard title bar).
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let sheetModel = SheetModel()

    func show(appState: AppState) {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsRootView(
                appState: appState,
                sheetModel: sheetModel
            ))
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "AI Subs — Settings"
            newWindow.styleMask = [.titled, .closable]
            newWindow.setContentSize(NSSize(width: 440, height: 480))
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            window = newWindow
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsRootView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var sheetModel: SheetModel

    var body: some View {
        VStack(spacing: 0) {
            subscriptionList
            Divider().opacity(0.3)
            HStack(spacing: 3) {
                Text("\(appState.config.subscriptions.count) subscriptions ·")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(appState.monthlyTotalUSD, format: .currency(code: "USD"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("/mo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    sheetModel.present(.add)
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            .padding(12)
        }
        .frame(minWidth: 440, minHeight: 480)
        .sheet(item: $sheetModel.session) { session in
            SubscriptionEditor(
                form: session.form,
                mode: session.mode,
                onSave: { appState.upsert($0) },
                onDelete: { appState.remove($0) },
                onClose: { sheetModel.dismiss() }
            )
        }
    }

    private var subscriptionList: some View {
        List {
            ForEach(appState.config.subscriptions) { subscription in
                Button {
                    sheetModel.present(.edit(subscription))
                } label: {
                    HStack {
                        Image(systemName: subscription.symbol)
                            .frame(width: 20)
                            .foregroundStyle(Color.accentColor)
                        Text(subscription.name)
                        Spacer()
                        Text(subscription.monthlyPriceUSD, format: .currency(code: "USD"))
                            .foregroundStyle(.secondary)
                            .font(.callout.monospacedDigit())
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.inset)
    }
}

extension SubscriptionEditor.Mode: Identifiable {
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let subscription): return "edit-\(subscription.id)"
        }
    }
}
