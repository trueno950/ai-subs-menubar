import AppKit
import SwiftUI
import ServiceManagement
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

/// Editable field state for the API tab.
@MainActor
final class APIKeyForm: ObservableObject {
    @Published var keys: [String: String] = [:]
    @Published var topUps: [String: String] = [:]
    @Published var thresholds: [String: String] = [:]
    @Published var status: String?

    func load(from appState: AppState) {
        for provider in appState.config.providers {
            topUps[provider.id] = provider.lastTopUpUSD.map { String(format: "%.2f", $0) } ?? ""
            thresholds[provider.id] = provider.alertThresholdUSD.map { String(format: "%.2f", $0) } ?? ""
        }
    }

    func binding(_ source: ReferenceWritableKeyPath<APIKeyForm, [String: String]>,
                 providerID: String) -> Binding<String> {
        Binding(
            get: { [weak self] in self?[keyPath: source][providerID] ?? "" },
            set: { [weak self] in self?[keyPath: source][providerID] = $0 }
        )
    }
}

/// Owns the regular settings window (activating, with a standard title bar).
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let sheetModel = SheetModel()
    private let apiKeyForm = APIKeyForm()
    private let generalForm = GeneralForm()

    func show(appState: AppState) {
        apiKeyForm.load(from: appState)

        if window == nil {
            let hosting = NSHostingController(rootView: SettingsRootView(
                appState: appState,
                sheetModel: sheetModel,
                apiKeyForm: apiKeyForm,
                generalForm: generalForm
            ))
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "AI Subs — Settings"
            newWindow.styleMask = [.titled, .closable]
            newWindow.setContentSize(NSSize(width: 460, height: 520))
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
    @ObservedObject var apiKeyForm: APIKeyForm
    @ObservedObject var generalForm: GeneralForm

    var body: some View {
        TabView {
            SubscriptionsTab(appState: appState, sheetModel: sheetModel)
                .tabItem { Label("Subscriptions", systemImage: "list.bullet") }
            APIKeysTab(appState: appState, form: apiKeyForm)
                .tabItem { Label("API", systemImage: "key.horizontal") }
            GeneralTab(appState: appState, form: generalForm)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(minWidth: 460, minHeight: 540)
    }
}

// MARK: - General tab

@MainActor
final class GeneralForm: ObservableObject {
    @Published var status: String?
}

struct GeneralTab: View {
    @ObservedObject var appState: AppState
    @ObservedObject var form: GeneralForm

    var body: some View {
        Form {
            Stepper(value: Binding(
                get: { appState.config.notifyDaysBeforeRenewal },
                set: { appState.config.notifyDaysBeforeRenewal = $0 }
            ), in: 0...14) {
                Text("Renewal notice: \(appState.config.notifyDaysBeforeRenewal) day(s) before, at 9:00")
            }

            Picker("Refresh API spend every", selection: Binding(
                get: { appState.config.refreshIntervalMinutes },
                set: { appState.config.refreshIntervalMinutes = $0 }
            )) {
                Text("5 minutes").tag(5)
                Text("15 minutes").tag(15)
                Text("30 minutes").tag(30)
                Text("60 minutes").tag(60)
            }

            Toggle("Launch at login", isOn: Binding(
                get: { SMAppService.mainApp.status == .enabled },
                set: { enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        form.status = nil
                    } catch {
                        form.status = "Launch at login: \(error.localizedDescription). " +
                            "Tip: install the app in /Applications first (scripts/install.sh)."
                    }
                }
            ))

            if let status = form.status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
    }
}

// MARK: - Subscriptions tab

struct SubscriptionsTab: View {
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

// MARK: - API tab

struct APIKeysTab: View {
    @ObservedObject var appState: AppState
    @ObservedObject var form: APIKeyForm

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Admin API keys for OpenAI/Anthropic; a standard z.ai API key works " +
                     "for the GLM Coding Plan quota. Keys are stored only in your login Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(appState.config.providers, id: \.id) { provider in
                    providerSection(provider)
                }

                if let status = form.status {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .onAppear { form.load(from: appState) }
    }

    private func providerSection(_ provider: ProviderSettings) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(provider.displayName, isOn: Binding(
                get: { appState.provider(provider.id)?.enabled ?? false },
                set: { newValue in
                    appState.updateProvider(provider.id) { settings in
                        settings.enabled = newValue
                    }
                }
            ))

            SecureField("Admin API key (\(provider.id == "openai" ? "sk-admin-..." : "sk-ant-admin01-..."))",
                        text: form.binding(\.keys, providerID: provider.id))

            HStack(spacing: 8) {
                TextField("Last top-up USD", text: form.binding(\.topUps, providerID: provider.id))
                    .frame(maxWidth: .infinity)
                TextField("Alert threshold USD", text: form.binding(\.thresholds, providerID: provider.id))
                    .frame(maxWidth: .infinity)
            }

            HStack {
                Button("Save") { save(provider) }
                Button("Test") { test(provider) }
                Spacer()
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func save(_ provider: ProviderSettings) {
        appState.updateProvider(provider.id) { settings in
            settings.lastTopUpUSD = Double(form.topUps[provider.id] ?? "")
            settings.alertThresholdUSD = Double(form.thresholds[provider.id] ?? "")
        }
        if let key = form.keys[provider.id], !key.isEmpty {
            do {
                try KeychainStore.set(key, for: "apikey-\(provider.id)")
                form.keys[provider.id] = ""
                form.status = "Saved \(provider.displayName): settings and key updated."
            } catch {
                form.status = "Keychain error: \(error.localizedDescription)"
            }
        } else {
            form.status = "Saved \(provider.displayName) settings (key unchanged)."
        }
    }

    private func test(_ provider: ProviderSettings) {
        form.status = "Testing \(provider.displayName)…"
        Task { @MainActor in
            let keyAccount = "apikey-\(provider.id)"
            guard let key = KeychainStore.get(keyAccount), !key.isEmpty else {
                form.status = "\(provider.displayName): no key stored. Paste and Save first."
                return
            }
            let client: CostFetching = provider.id == "openai"
                ? OpenAICostClient(apiKey: key)
                : AnthropicCostClient(apiKey: key)
            do {
                let usd = try await client.monthToDateSpend(now: Date())
                form.status = "\(provider.displayName) OK — month-to-date: \(usd.formatted(.currency(code: "USD")))"
            } catch {
                form.status = "\(provider.displayName) failed: \(error.localizedDescription)"
            }
        }
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
