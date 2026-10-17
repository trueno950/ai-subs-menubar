import Foundation
import UserNotifications
import AISubsCore

/// Local notification delivery for renewals and balance alerts.
@MainActor
enum Notifier {
    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// Schedules one notification per subscription, `daysBefore` days ahead at 9:00.
    static func scheduleRenewalNotifications(subscriptions: [AISubscription],
                                             daysBefore: Int,
                                             calendar: Calendar = .current) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let renewalIDs = requests.map(\.identifier).filter { $0.hasPrefix("renewal-") }
            center.removePendingNotificationRequests(withIdentifiers: renewalIDs)

            for subscription in subscriptions {
                let renewal = RenewalMath.nextRenewal(from: Date(),
                                                      dayOfMonth: subscription.renewalDay,
                                                      calendar: calendar)
                guard let noticeDate = calendar.date(byAdding: .day,
                                                     value: -max(0, daysBefore),
                                                     to: calendar.startOfDay(for: renewal)),
                      noticeDate > Date() else { continue }

                var components = calendar.dateComponents([.year, .month, .day], from: noticeDate)
                components.hour = 9
                components.minute = 0
                guard let triggerDate = calendar.date(from: components) else { continue }

                let content = UNMutableNotificationContent()
                content.title = subscription.name
                content.body = daysBefore == 0
                    ? "Renews today — \(subscription.monthlyPriceUSD.formatted(.currency(code: "USD")))/mo"
                    : "Renews in \(daysBefore) days — \(subscription.monthlyPriceUSD.formatted(.currency(code: "USD")))/mo"
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
                    repeats: false)
                let request = UNNotificationRequest(
                    identifier: "renewal-\(subscription.id.uuidString)",
                    content: content, trigger: trigger)
                center.add(request)
            }
        }
    }

    static func sendBalanceAlert(providerID: String, providerName: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(providerName) — spend alert"
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "balance-\(providerID)-\(Int(Date().timeIntervalSince1970))",
            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func sendQuotaAlert(providerID: String, providerName: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(providerName) — quota alert"
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "quota-\(providerID)-\(Int(Date().timeIntervalSince1970))",
            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
