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
                VStack(spacing: 8) {
                    sectionTitle("Plans")
                    if appState.config.subscriptions.isEmpty {
                        emptyState
                    } else {
                        ForEach(appState.config.subscriptions) { subscription in
                            SubscriptionCard(appState: appState, subscription: subscription)
                        }
                    }

                    sectionTitle("API usage")
                    apiSection
                }
                .padding(14)
            }
            Divider().opacity(0.25)
            footer
        }
        .frame(width: 360, height: 480)
        .background(VisualEffectBackground().ignoresSafeArea())
        .onAppear {
            Task { await appState.refreshSpend() }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.pink.gradient)
                Text("AI Subs")
                    .font(.headline)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                summaryMetric(
                    title: "Plans / month",
                    value: appState.monthlyTotalUSD.formatted(.currency(code: "USD")))
                Spacer(minLength: 4)
                summaryMetric(
                    title: "API spend / MTD",
                    value: appState.monthToDateAPIUSD?.formatted(.currency(code: "USD")) ?? "—")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(.system(.callout, design: .rounded).monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
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
        VStack(spacing: 4) {
            ForEach(appState.config.providers, id: \.id) { provider in
                APIProviderRow(appState: appState, provider: provider)
            }
            if !appState.config.providers.contains(where: { $0.enabled }) {
                Text("Enable providers and add keys in Settings → API.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            footerButton("gearshape", "Settings", action: onOpenSettings)
            Spacer()
            if appState.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 30, height: 24)
            } else {
                footerButton("arrow.clockwise", "Refresh") {
                    Task { await appState.refreshSpend() }
                }
            }
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

// MARK: - API provider row

struct APIProviderRow: View {
    @ObservedObject var appState: AppState
    let provider: ProviderSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Image(systemName: provider.id == "openai" ? "burst.fill" : (provider.id == "zai" ? "cpu" : "paintbrush.pointed.fill"))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.displayName)
                        .font(.body.weight(.medium))
                    caption
                }
                Spacer(minLength: 8)
                if !provider.enabled {
                    Text("Disabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if connectionState == .notConnected {
                    Label("Not connected", systemImage: "link.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if connectionState == .error {
                    Label("Error", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .help(appState.spend[provider.id]?.error ?? "Provider request failed")
                } else if let percent = quotaPercent {
                    Text("\(percent.formatted(.number.precision(.fractionLength(0))))% used")
                        .font(.system(.callout, design: .rounded).monospacedDigit().weight(.semibold))
                        .foregroundStyle(percent >= QuotaAlertRule.glmThresholdPercent ? Color.red : Color.primary)
                } else if provider.id == "zai", let snapshot = appState.spend[provider.id], snapshot.error == nil {
                    Text("—")
                        .font(.system(.callout, design: .rounded).monospacedDigit())
                        .foregroundStyle(.tertiary)
                } else if let snapshot = appState.spend[provider.id], snapshot.error == nil {
                    Text(snapshot.monthToDateUSD, format: .currency(code: "USD"))
                        .font(.system(.callout, design: .rounded).monospacedDigit().weight(.semibold))
                } else {
                    Text("—")
                        .font(.system(.callout, design: .rounded).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            if provider.enabled,
               let percent = quotaPercent,
               let progress = QuotaMath.progressFraction(usedPercent: percent) {
                HStack(spacing: 8) {
                    ProgressView(value: progress)
                        .tint(percent >= QuotaAlertRule.glmThresholdPercent ? .red : .accentColor)
                        .accessibilityLabel("GLM quota usage")
                        .accessibilityValue("\(percent.formatted(.number.precision(.fractionLength(0)))) percent used")
                    if let remaining = QuotaMath.remainingPercent(usedPercent: percent) {
                        Text("\(remaining.formatted(.number.precision(.fractionLength(0))))% remaining")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var quotaPercent: Double? {
        guard let percent = appState.spend[provider.id]?.quotaUsedPercent,
              percent.isFinite else { return nil }
        return percent
    }

    private var connectionState: ProviderConnectionState {
        appState.connectionState(for: provider)
    }

    @ViewBuilder
    private var caption: some View {
        if !provider.enabled {
            Text("disabled")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if connectionState == .notConnected {
            Text("Add an API key in Settings → API")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if let reset = appState.spend[provider.id]?.quotaResetAt {
            Text("resets \(reset.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        } else if provider.id == "zai", let snapshot = appState.spend[provider.id], snapshot.error == nil {
            Text("plan quota")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } else if connectionState == .error, let error = appState.spend[provider.id]?.error {
            Text(error)
                .font(.caption2)
                .foregroundStyle(.orange)
                .lineLimit(1)
        } else if let balance = appState.estimatedBalanceUSD(for: provider) {
            Text("est. balance \(balance, format: .currency(code: "USD"))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(balanceColor(balance))
        } else {
            Text("no top-up set")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func balanceColor(_ balance: Double) -> Color {
        if let threshold = provider.alertThresholdUSD, balance < threshold {
            return .red
        }
        return .secondary
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
        .padding(.vertical, 7)
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
