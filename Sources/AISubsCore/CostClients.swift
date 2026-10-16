import Foundation

// MARK: - Cost window helpers

public enum CostWindow {
    static var utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// First instant (UTC) of the month containing `date`.
    public static func monthStartUTC(for date: Date) -> Date {
        let comps = utcCalendar.dateComponents([.year, .month], from: date)
        return utcCalendar.date(from: comps) ?? date
    }

    /// UTC month range: [first day of month, first day of next month).
    public static func monthRangeUTC(for date: Date) -> (start: Date, end: Date) {
        let start = monthStartUTC(for: date)
        let end = utcCalendar.date(byAdding: .month, value: 1, to: start) ?? date
        return (start, end)
    }
}

// MARK: - Spend snapshot

public struct ProviderSpendSnapshot: Codable, Hashable, Sendable {
    public let providerID: String
    public let monthToDateUSD: Double
    public let fetchedAt: Date
    /// Non-nil when the last fetch failed; monthToDateUSD is then meaningless.
    public let error: String?
    /// GLM Coding Plan style quota (percentage used), when the provider
    /// exposes quota instead of monetary spend.
    public let quotaUsedPercent: Double?
    public let quotaResetAt: Date?

    public init(providerID: String, monthToDateUSD: Double, fetchedAt: Date,
                error: String?, quotaUsedPercent: Double? = nil,
                quotaResetAt: Date? = nil) {
        self.providerID = providerID
        self.monthToDateUSD = monthToDateUSD
        self.fetchedAt = fetchedAt
        self.error = error
        self.quotaUsedPercent = quotaUsedPercent
        self.quotaResetAt = quotaResetAt
    }
}

// MARK: - OpenAI

public enum OpenAICostParser {
    struct CostsResponse: Decodable {
        let data: [Bucket]
        let hasMore: Bool?
        let nextPage: String?

        enum CodingKeys: String, CodingKey {
            case data
            case hasMore = "has_more"
            case nextPage = "next_page"
        }

        struct Bucket: Decodable {
            let results: [CostResult]
        }

        struct CostResult: Decodable {
            let amount: Amount
        }

        struct Amount: Decodable {
            let value: Double
            let currency: String
        }
    }

    /// Sums all USD amounts across buckets in the response body.
    public static func monthToDate(from data: Data) throws -> Double {
        let response = try JSONDecoder().decode(CostsResponse.self, from: data)
        return response.data.flatMap(\.results)
            .filter { $0.amount.currency.lowercased() == "usd" }
            .reduce(0) { $0 + $1.amount.value }
    }
}

/// Fetches month-to-date spend via the official Usage/Cost API
/// (GET /v1/organization/costs, Admin API key).
public struct OpenAICostClient: CostFetching {
    static let baseURL = URL(string: "https://api.openai.com/v1/organization/costs")!
    public let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func monthToDateSpend(now: Date) async throws -> Double {
        let window = CostWindow.monthRangeUTC(for: now)
        var total = 0.0
        var page: String?
        var pages = 0

        repeat {
            var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
            var query = [
                "start_time=\(Int(window.start.timeIntervalSince1970))",
                "end_time=\(Int(window.end.timeIntervalSince1970))",
                "bucket_width=1d",
                "limit=31"
            ]
            if let page { query.append("page=\(page)") }
            components.query = query.joined(separator: "&")

            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.assertOK(response, data: data)
            total += try OpenAICostParser.monthToDate(from: data)

            let decoded = try JSONDecoder().decode(OpenAICostParser.CostsResponse.self, from: data)
            page = (decoded.hasMore == true ? decoded.nextPage : nil)
            pages += 1
        } while page != nil && pages < 5

        return total
    }

    static func assertOK(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw CostClientError.http(status: http.statusCode, body: body)
        }
    }
}

// MARK: - Anthropic

public enum AnthropicCostParser {
    struct CostReport: Decodable {
        let data: [Entry]
        let hasMore: Bool?
        let nextPage: String?

        enum CodingKeys: String, CodingKey {
            case data
            case hasMore = "has_more"
            case nextPage = "next_page"
        }

        struct Entry: Decodable {
            /// API reports costs as decimal strings in cents; tolerate numbers too.
            let cost: FlexibleNumber
        }
    }

    /// Sums all cost entries, converting cents to dollars.
    public static func monthToDate(from data: Data) throws -> Double {
        let report = try JSONDecoder().decode(CostReport.self, from: data)
        return report.data.reduce(0) { $0 + $1.cost.value } / 100
    }
}

/// Decodes JSON numbers that may arrive as `"1234"` (string) or `1234`.
public struct FlexibleNumber: Decodable, Sendable {
    public let value: Double

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self),
           let parsed = Double(string) {
            value = parsed
        } else if let number = try? container.decode(Double.self) {
            value = number
        } else {
            throw DecodingError.typeMismatch(
                Double.self,
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Expected numeric cost or numeric string")
            )
        }
    }
}

/// Fetches month-to-date spend via the Anthropic Admin Cost API
/// (GET /v1/organizations/cost_report, Admin API key).
public struct AnthropicCostClient: CostFetching {
    static let baseURL = URL(string: "https://api.anthropic.com/v1/organizations/cost_report")!
    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    public let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func monthToDateSpend(now: Date) async throws -> Double {
        let window = CostWindow.monthRangeUTC(for: now)
        var total = 0.0
        var page: String?
        var pages = 0

        repeat {
            var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
            var query = [
                "starting_at=\(Self.isoFormatter.string(from: window.start))",
                "ending_at=\(Self.isoFormatter.string(from: window.end))",
                "bucket_width=1d",
                "limit=31"
            ]
            if let page { query.append("page=\(page)") }
            components.query = query.joined(separator: "&").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

            var request = URLRequest(url: components.url!)
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

            let (data, response) = try await URLSession.shared.data(for: request)
            try OpenAICostClient.assertOK(response, data: data)
            total += try AnthropicCostParser.monthToDate(from: data)

            let decoded = try JSONDecoder().decode(AnthropicCostParser.CostReport.self, from: data)
            page = (decoded.hasMore == true ? decoded.nextPage : nil)
            pages += 1
        } while page != nil && pages < 5

        return total
    }
}

// MARK: - Z.ai (GLM Coding Plan)

public struct ZaiPlanQuota: Hashable, Sendable {
    public let usedPercent: Double
    public let remaining: Double?
    public let resetAt: Date?

    public init(usedPercent: Double, remaining: Double?, resetAt: Date?) {
        self.usedPercent = usedPercent
        self.remaining = remaining
        self.resetAt = resetAt
    }
}

public enum ZaiQuotaParser {
    struct QuotaResponse: Decodable {
        let data: QuotaData?

        struct QuotaData: Decodable {
            let limits: [Limit]?
        }

        struct Limit: Decodable {
            let type: String?
            let percentage: Double?
            let usage: Double?
            let currentValue: Double?
            let remaining: Double?
            let nextResetTime: Double?
        }
    }

    /// Parses the undocumented-but-stable Coding Plan quota endpoint used by
    /// the z.ai subscription UI (`/api/monitor/usage/quota/limit`).
    public static func parse(from data: Data) throws -> ZaiPlanQuota {
        let response = try JSONDecoder().decode(QuotaResponse.self, from: data)
        guard let limit = response.data?.limits?.first(where: { ($0.type ?? "").contains("LIMIT") })
        else {
            throw CostClientError.http(status: 0,
                                       body: "No quota limit entry in response")
        }

        let usedPercent: Double
        if let percentage = limit.percentage {
            usedPercent = percentage
        } else if let used = limit.currentValue, let total = limit.usage, total > 0 {
            usedPercent = used / total * 100
        } else {
            usedPercent = 0
        }

        let resetAt: Date?
        if let milliseconds = limit.nextResetTime {
            resetAt = Date(timeIntervalSince1970: milliseconds / 1000)
        } else {
            resetAt = nil
        }

        return ZaiPlanQuota(usedPercent: usedPercent,
                            remaining: limit.remaining,
                            resetAt: resetAt)
    }
}

public protocol QuotaFetching: Sendable {
    func planQuota(now: Date) async throws -> ZaiPlanQuota
}

/// Queries the GLM Coding Plan quota (works with a z.ai API key).
public struct ZaiQuotaClient: QuotaFetching {
    static let baseURL = URL(string: "https://api.z.ai/api/monitor/usage/quota/limit")!
    public let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func planQuota(now: Date) async throws -> ZaiPlanQuota {
        var request = URLRequest(url: Self.baseURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        try OpenAICostClient.assertOK(response, data: data)
        return try ZaiQuotaParser.parse(from: data)
    }
}

// MARK: - Errors

public enum CostClientError: LocalizedError {
    case http(status: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case let .http(status, body):
            return "HTTP \(status): \(body.isEmpty ? "no details" : body)"
        }
    }
}

// MARK: - Client abstraction

public protocol CostFetching: Sendable {
    func monthToDateSpend(now: Date) async throws -> Double
}
