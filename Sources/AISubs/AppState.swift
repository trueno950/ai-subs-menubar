import Foundation
import Combine
import AISubsCore

/// Single source of truth for configuration, shared by the popover and the
/// settings window. Mutations persist immediately.
@MainActor
final class AppState: ObservableObject {
    @Published var config: AppConfig {
        didSet { persist() }
    }

    private let store: ConfigStore

    nonisolated static func makeDefaultStore() -> ConfigStore {
        if let store = try? ConfigStore(directory: ConfigStore.appSupportDirectory()) {
            return store
        }
        return try! ConfigStore(directory: FileManager.default.temporaryDirectory)
    }

    init(store: ConfigStore = AppState.makeDefaultStore()) {
        self.store = store
        self.config = (try? store.load()) ?? .default
    }

    private func persist() {
        try? store.save(config)
    }

    // MARK: - Derived values

    var monthlyTotalUSD: Double {
        RenewalMath.monthlyTotal(config.subscriptions)
    }

    func nextRenewal(for subscription: AISubscription) -> Date {
        RenewalMath.nextRenewal(from: Date(), dayOfMonth: subscription.renewalDay,
                                calendar: .current)
    }

    func daysUntilRenewal(for subscription: AISubscription) -> Int {
        RenewalMath.daysUntil(nextRenewal(for: subscription), from: Date(), calendar: .current)
    }

    // MARK: - Live API spend

    @Published var spend: [String: ProviderSpendSnapshot] = [:]
    @Published private(set) var isRefreshing = false

    /// Fetches month-to-date spend for every enabled provider.
    func refreshSpend() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        for provider in config.providers {
            guard provider.enabled else { continue }
            let keyAccount = "apikey-\(provider.id)"
            guard let key = KeychainStore.get(keyAccount), !key.isEmpty else {
                spend[provider.id] = ProviderSpendSnapshot(
                    providerID: provider.id, monthToDateUSD: 0, fetchedAt: Date(),
                    error: "No API key configured")
                continue
            }

            let client: CostFetching = provider.id == "openai"
                ? OpenAICostClient(apiKey: key)
                : AnthropicCostClient(apiKey: key)

            do {
                let usd = try await client.monthToDateSpend(now: Date())
                spend[provider.id] = ProviderSpendSnapshot(
                    providerID: provider.id, monthToDateUSD: usd, fetchedAt: Date(), error: nil)
            } catch {
                spend[provider.id] = ProviderSpendSnapshot(
                    providerID: provider.id, monthToDateUSD: 0, fetchedAt: Date(),
                    error: error.localizedDescription)
            }
        }
    }

    /// Estimated remaining credit, only when the user set a top-up.
    func estimatedBalanceUSD(for provider: ProviderSettings) -> Double? {
        guard let topUp = provider.lastTopUpUSD else { return nil }
        let snapshot = spend[provider.id]
        let mtd = (snapshot?.error == nil) ? (snapshot?.monthToDateUSD ?? 0) : 0
        return BalanceMath.estimatedBalance(topUpUSD: topUp, monthToDateSpendUSD: mtd)
    }

    /// Rising-edge alert evaluation after each spend refresh. Returns the
    /// provider alerts that should be delivered now.
    func alertMessagesAfterRefresh() -> [(providerID: String, providerName: String, message: String)] {
        var messages: [(String, String, String)] = []
        for provider in config.providers where provider.enabled {
            guard let threshold = provider.alertThresholdUSD else { continue }
            let snapshot = spend[provider.id]
            let mtd = (snapshot?.error == nil) ? (snapshot?.monthToDateUSD ?? 0) : 0
            let estimated = estimatedBalanceUSD(for: provider)
            let nowAlerting = BalanceMath.shouldAlert(estimatedBalanceUSD: estimated,
                                                      monthToDateSpendUSD: mtd,
                                                      thresholdUSD: threshold)
            var detector = alertDetectors[provider.id] ?? AlertEdgeDetector()
            if detector.shouldFire(nowAlerting: nowAlerting) {
                let body: String
                if let estimated {
                    body = "Estimated balance \(estimated.formatted(.currency(code: "USD"))) is below \(threshold.formatted(.currency(code: "USD")))"
                } else {
                    body = "Month-to-date spend \(mtd.formatted(.currency(code: "USD"))) exceeds \(threshold.formatted(.currency(code: "USD")))"
                }
                messages.append((provider.id, provider.displayName, body))
            }
            alertDetectors[provider.id] = detector
        }
        return messages
    }

    private var alertDetectors: [String: AlertEdgeDetector] = [:]

    // MARK: - Mutations

    func upsert(_ subscription: AISubscription) {
        if let index = config.subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            config.subscriptions[index] = subscription
        } else {
            config.subscriptions.append(subscription)
        }
    }

    func remove(_ subscription: AISubscription) {
        config.subscriptions.removeAll { $0.id == subscription.id }
    }

    func provider(_ id: String) -> ProviderSettings? {
        config.providers.first { $0.id == id }
    }

    func updateProvider(_ id: String, mutate: (inout ProviderSettings) -> Void) {
        guard let index = config.providers.firstIndex(where: { $0.id == id }) else { return }
        mutate(&config.providers[index])
    }
}
