import Foundation

/// Pure date math for subscription renewals.
public enum RenewalMath {
    /// Next renewal date at the given day of month. Day 31 in a 30-day month
    /// clamps to that month's last day. If the day already passed this month
    /// (or is earlier today), the next occurrence is next month.
    public static func nextRenewal(from date: Date, dayOfMonth: Int, calendar: Calendar) -> Date {
        let maxDayThisMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 28

        var comps = calendar.dateComponents([.year, .month], from: date)
        comps.day = min(max(1, dayOfMonth), maxDayThisMonth)
        guard let candidate = calendar.date(from: comps) else { return date }

        if candidate >= calendar.startOfDay(for: date) {
            return candidate
        }

        let nextMonthReference = calendar.date(byAdding: .month, value: 1, to: candidate) ?? date
        let maxDayNextMonth = calendar.range(of: .day, in: .month, for: nextMonthReference)?.count ?? 28
        var nextComps = calendar.dateComponents([.year, .month], from: nextMonthReference)
        nextComps.day = min(max(1, dayOfMonth), maxDayNextMonth)
        return calendar.date(from: nextComps) ?? nextMonthReference
    }

    /// Whole days from `date` to `target` (0 when same day).
    public static func daysUntil(_ target: Date, from date: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: target)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Sum of all monthly prices in USD.
    public static func monthlyTotal(_ subscriptions: [AISubscription]) -> Double {
        subscriptions.reduce(0) { $0 + $1.monthlyPriceUSD }
    }
}

/// Rising-edge detector so an alert fires once per crossing, not every refresh.
public struct AlertEdgeDetector: Sendable {
    private var wasAlerting = false

    public init() {}

    /// Returns true only on the transition from healthy to alerting.
    public mutating func shouldFire(nowAlerting: Bool) -> Bool {
        let fire = nowAlerting && !wasAlerting
        wasAlerting = nowAlerting
        return fire
    }
}

/// Pure math for estimated API balances and alerts.
public enum BalanceMath {
    /// Estimated remaining credit: last manual top-up minus month-to-date spend.
    /// May be negative to surface an overdraft.
    public static func estimatedBalance(topUpUSD: Double, monthToDateSpendUSD: Double) -> Double {
        topUpUSD - monthToDateSpendUSD
    }

    /// Alert rule: with a configured top-up, alert when the estimated balance
    /// falls below the threshold; without one, alert when month-to-date spend
    /// exceeds the threshold.
    public static func shouldAlert(estimatedBalanceUSD: Double?,
                                   monthToDateSpendUSD: Double,
                                   thresholdUSD: Double) -> Bool {
        if let balance = estimatedBalanceUSD {
            return balance < thresholdUSD
        }
        return monthToDateSpendUSD > thresholdUSD
    }
}
