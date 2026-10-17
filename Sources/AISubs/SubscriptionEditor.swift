import SwiftUI
import AISubsCore

/// Local editable state for the subscription form. Lives on an
/// ObservableObject because @State macros are unavailable without full Xcode.
@MainActor
final class EditorForm: ObservableObject {
    @Published var name: String
    @Published var priceText: String
    @Published var renewalDay: Int
    @Published var symbol: String
    let priceIsSuggestion: Bool

    init(name: String = "", priceText: String = "", renewalDay: Int = 1,
         symbol: String = "sparkles", priceIsSuggestion: Bool = false) {
        self.name = name
        self.priceText = priceText
        self.renewalDay = renewalDay
        self.symbol = symbol
        self.priceIsSuggestion = priceIsSuggestion
    }

    static func forSubscription(_ subscription: AISubscription) -> EditorForm {
        EditorForm(name: subscription.name,
                   priceText: String(format: "%.2f", subscription.monthlyPriceUSD),
                   renewalDay: subscription.renewalDay,
                   symbol: subscription.symbol)
    }

    static func forPreset(_ preset: AISubscriptionQuickAddPreset) -> EditorForm {
        EditorForm(name: preset.displayName,
                   priceText: String(format: "%.2f", preset.suggestedMonthlyPriceUSD),
                   renewalDay: 1,
                   symbol: preset.symbol,
                   priceIsSuggestion: true)
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (Double(priceText) ?? -1) >= 0
    }
}

/// Form for adding or editing one subscription.
struct SubscriptionEditor: View {
    enum Mode {
        case add
        case edit(AISubscription)

        var existing: AISubscription? {
            if case .edit(let subscription) = self { return subscription }
            return nil
        }
    }

    @ObservedObject var form: EditorForm
    let mode: Mode
    let onSave: (AISubscription) -> Void
    let onClose: () -> Void

    static let symbolChoices = [
        "sparkles", "brain", "paintbrush", "cursorarrow", "wand.and.stars",
        "questionmark.circle", "photo", "music.note", "video", "terminal",
        "paperplane.fill", "waveform"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(mode.existing == nil ? "Add Subscription" : "Edit Subscription")
                .font(.headline)

            if form.priceIsSuggestion {
                Text("Suggested price. Confirm the amount and renewal day before saving.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Form {
                TextField("Name", text: $form.name)
                TextField("Monthly price (USD)", text: $form.priceText)
                Stepper(value: $form.renewalDay, in: 1...31) {
                    Text("Renewal day: \(form.renewalDay)")
                }
                Picker("Icon", selection: $form.symbol) {
                    ForEach(SubscriptionEditor.symbolChoices, id: \.self) { choice in
                        Image(systemName: choice).tag(choice)
                    }
                }
            }

            if let current = mode.existing {
                Button {
                    onDelete(current)
                } label: {
                    Label("Remove subscription", systemImage: "trash")
                }
            }

            Spacer()

            HStack {
                Button("Cancel") { onClose() }
                Spacer()
                Button("Save") { save() }
                    .disabled(!form.isValid)
            }
        }
        .padding(18)
        .frame(width: 340, height: 330)
    }

    private var onDelete: (AISubscription) -> Void { _onDelete }

    private let _onDelete: (AISubscription) -> Void

    init(form: EditorForm, mode: Mode,
         onSave: @escaping (AISubscription) -> Void,
         onDelete: @escaping (AISubscription) -> Void = { _ in },
         onClose: @escaping () -> Void) {
        self.form = form
        self.mode = mode
        self.onSave = onSave
        self._onDelete = onDelete
        self.onClose = onClose
    }

    private func save() {
        var updated = mode.existing ?? AISubscription(name: form.name,
                                                      monthlyPriceUSD: 0,
                                                      renewalDay: form.renewalDay,
                                                      symbol: form.symbol)
        updated.name = form.name.trimmingCharacters(in: .whitespaces)
        updated.monthlyPriceUSD = Double(form.priceText) ?? 0
        updated.renewalDay = form.renewalDay
        updated.symbol = form.symbol
        onSave(updated)
        onClose()
    }
}
