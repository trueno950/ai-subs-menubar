import Foundation

/// A manually tracked subscription (ChatGPT Plus, Claude Pro, Cursor, ...).
public struct AISubscription: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var monthlyPriceUSD: Double
    public var renewalDay: Int
    public var symbol: String

    public init(id: UUID = UUID(), name: String, monthlyPriceUSD: Double,
                renewalDay: Int, symbol: String) {
        self.id = id
        self.name = name
        self.monthlyPriceUSD = monthlyPriceUSD
        self.renewalDay = max(1, min(31, renewalDay))
        self.symbol = symbol
    }
}

/// Configuration for one live API provider ("openai" or "anthropic").
public struct ProviderSettings: Codable, Hashable, Sendable {
    public var id: String
    public var displayName: String
    public var enabled: Bool
    /// Last manual top-up the user made, for estimated-balance math.
    public var lastTopUpUSD: Double?
    /// Alert when estimated balance falls below (or MTD spend exceeds) this value.
    public var alertThresholdUSD: Double?

    public init(id: String, displayName: String, enabled: Bool = false,
                lastTopUpUSD: Double? = nil, alertThresholdUSD: Double? = nil) {
        self.id = id
        self.displayName = displayName
        self.enabled = enabled
        self.lastTopUpUSD = lastTopUpUSD
        self.alertThresholdUSD = alertThresholdUSD
    }
}

/// Root configuration persisted as JSON in Application Support.
public struct AppConfig: Codable, Hashable, Sendable {
    public var subscriptions: [AISubscription]
    public var providers: [ProviderSettings]
    public var notifyDaysBeforeRenewal: Int
    public var refreshIntervalMinutes: Int

    public static let `default` = AppConfig(
        subscriptions: [],
        providers: [
            ProviderSettings(id: "openai", displayName: "OpenAI"),
            ProviderSettings(id: "anthropic", displayName: "Anthropic"),
            ProviderSettings(id: "zai", displayName: "Z.ai GLM")
        ],
        notifyDaysBeforeRenewal: 3,
        refreshIntervalMinutes: 15
    )
}

extension AppConfig {
    /// Adds default providers missing from configs saved by older versions.
    public func mergingMissingDefaultProviders() -> AppConfig {
        var updated = self
        for provider in AppConfig.default.providers
        where !updated.providers.contains(where: { $0.id == provider.id }) {
            updated.providers.append(provider)
        }
        return updated
    }
}
