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
