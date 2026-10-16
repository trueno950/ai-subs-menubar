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
        AISubscription(name: "ChatGPT Plus", monthlyPriceUSD: 20, renewalDay: 12, symbol: "sparkles"),
        AISubscription(name: "Claude Pro", monthlyPriceUSD: 20, renewalDay: 28, symbol: "paintbrush"),
        AISubscription(name: "Cursor", monthlyPriceUSD: 9.99, renewalDay: 5, symbol: "cursorarrow")
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
    config.subscriptions.append(AISubscription(name: "Perplexity Pro", monthlyPriceUSD: 20, renewalDay: 7, symbol: "questionmark.circle"))
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
    config.subscriptions.append(AISubscription(name: "Midjourney", monthlyPriceUSD: 30, renewalDay: 2, symbol: "wand.and.stars"))
    try store.save(config)

    let loaded = try ConfigStore(directory: dir).load()
    checkEqual(loaded, config, "saved config reloads identical from disk")

    try? FileManager.default.removeItem(at: dir)
}

// MARK: - CostWindow

do {
    let start = CostWindow.monthStartUTC(for: date(2026, 3, 10))
    checkEqual(cal.dateComponents([.year, .month, .day], from: start),
               DateComponents(year: 2026, month: 3, day: 1),
               "monthStartUTC is first day of the month (UTC)")
    let range = CostWindow.monthRangeUTC(for: date(2026, 1, 15))
    checkEqual(cal.dateComponents([.year, .month, .day], from: range.end),
               DateComponents(year: 2026, month: 2, day: 1),
               "monthRangeUTC end is exclusive first day of next month")
}

// MARK: - OpenAI costs parsing

do {
    let sample = """
    {"object":"list","data":[
      {"object":"bucket","start_time":1740787200,"end_time":1740873600,"results":[
        {"object":"organization.costs.result","amount":{"value":1.25,"currency":"usd"},"line_item":null,"project_id":null,"organization_id":"org-1"},
        {"object":"organization.costs.result","amount":{"value":0.75,"currency":"usd"},"line_item":null,"project_id":null,"organization_id":"org-1"}]},
      {"object":"bucket","start_time":1740873600,"end_time":1740960000,"results":[
        {"object":"organization.costs.result","amount":{"value":2.0,"currency":"usd"},"line_item":null,"project_id":null,"organization_id":"org-1"}]},
      {"object":"bucket","start_time":1740960000,"end_time":1741046400,"results":[]}
    ],"has_more":false,"next_page":null}
    """
    let total = try OpenAICostParser.monthToDate(from: Data(sample.utf8))
    check(abs(total - 4.0) < 0.0001, "OpenAI bucket results sum to month-to-date spend (got \(total))")
}

// MARK: - Anthropic cost report parsing

do {
    let sample = """
    {"data":[
      {"cost":"1234","currency":"usd","description":"Claude Sonnet","starting_at":"2026-03-01T00:00:00Z","ending_at":"2026-03-02T00:00:00Z"},
      {"cost":"766","currency":"usd","description":"Web Search","starting_at":"2026-03-02T00:00:00Z","ending_at":"2026-03-03T00:00:00Z"}
    ],"has_more":false,"next_page":null}
    """
    let total = try AnthropicCostParser.monthToDate(from: Data(sample.utf8))
    check(abs(total - 20.0) < 0.0001, "Anthropic cent strings sum to dollars (got \(total))")
}
do {
    let sample = """
    {"data":[{"cost":550,"currency":"usd","description":"Claude"}],"has_more":false}
    """
    let total = try AnthropicCostParser.monthToDate(from: Data(sample.utf8))
    check(abs(total - 5.5) < 0.0001, "Anthropic parser tolerates numeric cent values (got \(total))")
}

// MARK: - AlertEdgeDetector (fire on rising edge only)

do {
    var detector = AlertEdgeDetector()
    check(!detector.shouldFire(nowAlerting: false), "no alert while healthy")
    check(detector.shouldFire(nowAlerting: true), "fires when crossing into alert state")
    check(!detector.shouldFire(nowAlerting: true), "stays silent while already alerting")
    check(!detector.shouldFire(nowAlerting: false), "silent on recovery")
    check(detector.shouldFire(nowAlerting: true), "fires again on a new crossing")
}

// MARK: - ZaiQuotaParser (GLM Coding Plan quota)

do {
    let sample = """
    {"code":200,"data":{"limits":[
      {"type":"CREDIT_LIMIT","unit":3,"number":5,"usage":800000000,"currentValue":127694464,"remaining":672305536,"percentage":15,"nextResetTime":1770648402389}
    ]}}
    """
    let quota = try ZaiQuotaParser.parse(from: Data(sample.utf8))
    check(abs(quota.usedPercent - 15) < 0.001, "ZaiQuotaParser uses provided percentage (got \(quota.usedPercent))")
    check(abs((quota.remaining ?? 0) - 672305536) < 0.001, "ZaiQuotaParser keeps remaining quota")
    check(quota.resetAt != nil && abs(quota.resetAt!.timeIntervalSince1970 - 1770648402.389) < 0.01,
          "ZaiQuotaParser converts epoch-milliseconds reset time")
}
do {
    let sample = """
    {"code":200,"data":{"limits":[
      {"type":"SOMETHING_ELSE","percentage":99},
      {"type":"TOKENS_LIMIT","number":1000,"usage":1000,"currentValue":800,"remaining":200}
    ]}}
    """
    let quota = try ZaiQuotaParser.parse(from: Data(sample.utf8))
    check(abs(quota.usedPercent - 80) < 0.001, "ZaiQuotaParser computes percent from usage when missing (got \(quota.usedPercent))")
    check(quota.resetAt == nil, "ZaiQuotaParser tolerates missing reset time")
}

// MARK: - AppConfig provider migration

do {
    var legacy = AppConfig.default
    legacy.providers.removeLast() // simulate a config saved before zai existed
    let migrated = legacy.mergingMissingDefaultProviders()
    check(migrated.providers.contains(where: { $0.id == "zai" }),
          "migration adds zai provider to configs saved before it existed")
    let custom = ProviderSettings(id: "custom-thing", displayName: "Custom")
    var withCustom = AppConfig.default
    withCustom.providers.append(custom)
    check(withCustom.mergingMissingDefaultProviders().providers.contains(custom),
          "migration preserves custom providers")
}

// MARK: - Summary

print("")
if failures == 0 {
    print("ALL \(total) CHECKS PASSED")
} else {
    print("\(failures)/\(total) CHECKS FAILED")
    exit(1)
}
