import Foundation
import AISubsCore

var failures = 0
var total = 0

func check(_ condition: Bool, _ label: String) {
    total += 1
    if condition {
        print("ok   \(label)")
    } else {
        failures += 1
        print("FAIL \(label)")
    }
}

func checkEqual<T: Equatable>(_ a: T, _ b: T, _ label: String) {
    total += 1
    if a == b {
        print("ok   \(label)")
    } else {
        failures += 1
        print("FAIL \(label) — got \(a), expected \(b)")
    }
}

var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(identifier: "UTC")!

func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
}

// MARK: - RenewalMath.nextRenewal

do {
    let next = RenewalMath.nextRenewal(from: date(2026, 3, 10), dayOfMonth: 15, calendar: cal)
    checkEqual(cal.dateComponents([.day, .month], from: next),
               DateComponents(month: 3, day: 15),
               "renewal later this month stays this month")
}
do {
    let next = RenewalMath.nextRenewal(from: date(2026, 3, 20), dayOfMonth: 15, calendar: cal)
    checkEqual(cal.dateComponents([.day, .month], from: next),
               DateComponents(month: 4, day: 15),
               "renewal day already passed rolls to next month")
}
do {
    let next = RenewalMath.nextRenewal(from: date(2026, 4, 10), dayOfMonth: 31, calendar: cal)
    checkEqual(cal.component(.day, from: next), 30,
               "day 31 clamps to April 30")
}
do {
    let next = RenewalMath.nextRenewal(from: date(2026, 3, 15), dayOfMonth: 15, calendar: cal)
    checkEqual(cal.dateComponents([.day, .month], from: next),
               DateComponents(month: 3, day: 15),
               "renewal today counts as today")
}

// MARK: - RenewalMath.daysUntil / monthlyTotal

checkEqual(RenewalMath.daysUntil(date(2026, 3, 15), from: date(2026, 3, 10), calendar: cal), 5,
           "daysUntil counts whole days")
checkEqual(RenewalMath.daysUntil(date(2026, 3, 15), from: date(2026, 3, 15), calendar: cal), 0,
           "daysUntil is zero on the renewal day")

do {
    let subs = [
        Subscription(name: "ChatGPT Plus", monthlyPriceUSD: 20, renewalDay: 12, symbol: "sparkles"),
        Subscription(name: "Claude Pro", monthlyPriceUSD: 20, renewalDay: 28, symbol: "paintbrush"),
        Subscription(name: "Cursor", monthlyPriceUSD: 9.99, renewalDay: 5, symbol: "cursorarrow")
    ]
    let totalPrice = RenewalMath.monthlyTotal(subs)
    check(abs(totalPrice - 49.99) < 0.001, "monthlyTotal sums all subscriptions (got \(totalPrice))")
}
checkEqual(RenewalMath.monthlyTotal([]), 0, "monthlyTotal of empty list is zero")

// MARK: - BalanceMath

checkEqual(BalanceMath.estimatedBalance(topUpUSD: 50, monthToDateSpendUSD: 35.68), 14.32,
           "estimated balance = top-up minus month-to-date spend")
check(BalanceMath.estimatedBalance(topUpUSD: 10, monthToDateSpendUSD: 12) < 0,
      "estimated balance may go negative (overdraft visible)")

check(BalanceMath.shouldAlert(estimatedBalanceUSD: 3.87, monthToDateSpendUSD: 10, thresholdUSD: 5),
      "alert when estimated balance below threshold")
check(!BalanceMath.shouldAlert(estimatedBalanceUSD: 14.32, monthToDateSpendUSD: 10, thresholdUSD: 5),
      "no alert when estimated balance above threshold")
check(BalanceMath.shouldAlert(estimatedBalanceUSD: nil, monthToDateSpendUSD: 6, thresholdUSD: 5),
      "without top-up, alert when month-to-date spend exceeds threshold")
check(!BalanceMath.shouldAlert(estimatedBalanceUSD: nil, monthToDateSpendUSD: 4, thresholdUSD: 5),
      "without top-up, no alert when month-to-date spend below threshold")

// MARK: - AppConfig round-trip

do {
    var config = AppConfig.default
    config.subscriptions.append(Subscription(name: "Perplexity Pro", monthlyPriceUSD: 20, renewalDay: 7, symbol: "questionmark.circle"))
    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
    checkEqual(decoded, config, "AppConfig survives JSON round-trip unchanged")
}
do {
    let config = AppConfig.default
    check(!config.providers.isEmpty, "default config ships provider entries")
    check(config.notifyDaysBeforeRenewal > 0, "default config has renewal notice window")
}

// MARK: - ConfigStore round-trip

do {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("aisubs-tests-\(UUID().uuidString)")
    let store = try ConfigStore(directory: dir)
    check(try store.load() == nil, "fresh store has no config yet")

    var config = AppConfig.default
    config.subscriptions.append(Subscription(name: "Midjourney", monthlyPriceUSD: 30, renewalDay: 2, symbol: "wand.and.stars"))
    try store.save(config)

    let loaded = try ConfigStore(directory: dir).load()
    checkEqual(loaded, config, "saved config reloads identical from disk")

    try? FileManager.default.removeItem(at: dir)
}

// MARK: - Summary

print("")
if failures == 0 {
    print("ALL \(total) CHECKS PASSED")
} else {
    print("\(failures)/\(total) CHECKS FAILED")
    exit(1)
}
