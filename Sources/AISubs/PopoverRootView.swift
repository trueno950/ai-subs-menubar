import SwiftUI
import AISubsCore

struct PopoverRootView: View {
    @ObservedObject var appState: AppState
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.25)
            ScrollView {
                VStack(spacing: 12) {
                    sectionTitle("Subscriptions")
                    if appState.config.subscriptions.isEmpty {
                        emptyState
                    } else {
                        ForEach(appState.config.subscriptions) { subscription in
                            SubscriptionCard(appState: appState, subscription: subscription)
                        }
                    }

                    sectionTitle("API spend (month)")
                    apiSection
                }
                .padding(14)
            }
            Divider().opacity(0.25)
            footer
        }
        .frame(width: 360, height: 480)
        .background(VisualEffectBackground().ignoresSafeArea())
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.pink.gradient)
            Text("AI Subs")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(appState.monthlyTotalUSD, format: .currency(code: "USD"))
                    .font(.system(.title3, design: .rounded).monospacedDigit().weight(.bold))
                Text("per month")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("No subscriptions yet")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Add yours from the gear button below.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }

    private var apiSection: some View {
        VStack(spacing: 8) {
            ForEach(appState.config.providers, id: \.id) { provider in
                HStack {
                    Image(systemName: provider.id == "openai" ? "burst.fill" : "paintbrush.pointed.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    Text(provider.displayName)
                    Spacer()
                    Text("—")
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            Text("Live spend arrives with API keys (Settings → API).")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            footerButton("gearshape", "Settings", action: onOpenSettings)
            Spacer()
            footerButton("arrow.clockwise", "Refresh", action: {})
            footerButton("power", "Quit", action: onQuit)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func footerButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 30, height: 24)
        }
        .buttonStyle(.plain)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .help(label)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 2)
    }
}

// MARK: - AISubscription card

struct SubscriptionCard: View {
    @ObservedObject var appState: AppState
    let subscription: AISubscription

    var body: some View {
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(.system(size: 13, weight: .semibold))
                Text(renewalText)
                    .font(.caption)
                    .foregroundStyle(renewalColor)
            }
            Spacer()
            Text(subscription.monthlyPriceUSD, format: .currency(code: "USD"))
                .font(.system(.callout, design: .rounded).monospacedDigit().weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var icon: some View {
        Image(systemName: subscription.symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var daysLeft: Int {
        appState.daysUntilRenewal(for: subscription)
    }

    private var renewalText: String {
        let days = daysLeft
        if days == 0 { return "Renews today" }
        if days == 1 { return "Renews tomorrow" }
        return "Renews in \(days) days"
    }

    private var renewalColor: Color {
        let noticeWindow = appState.config.notifyDaysBeforeRenewal
        if daysLeft <= 1 { return .red }
        if daysLeft <= noticeWindow { return .orange }
        return .secondary
    }
}
