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

/// Editable initial values for the most common monthly AI plans.
/// Prices are regular USD list-price suggestions and may vary by region or promotion.
public enum AISubscriptionQuickAddPreset: String, CaseIterable, Identifiable, Sendable {
    case chatGPTPlus
    case claudePro
    case glmCodingPlanLite
    case glmCodingPlanPro
    case glmCodingPlanMax

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .chatGPTPlus: return "ChatGPT Plus"
        case .claudePro: return "Claude Pro"
        case .glmCodingPlanLite: return "GLM Coding Plan Lite"
        case .glmCodingPlanPro: return "GLM Coding Plan Pro"
        case .glmCodingPlanMax: return "GLM Coding Plan Max"
        }
    }

    public var suggestedMonthlyPriceUSD: Double {
        switch self {
        case .chatGPTPlus, .claudePro: return 20
        case .glmCodingPlanLite: return 18
        case .glmCodingPlanPro: return 80
        case .glmCodingPlanMax: return 168
        }
    }

    public var symbol: String {
        switch self {
        case .chatGPTPlus: return "sparkles"
        case .claudePro: return "paintbrush.pointed.fill"
        case .glmCodingPlanLite, .glmCodingPlanPro, .glmCodingPlanMax: return "cpu"
        }
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
