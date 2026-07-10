import SwiftUI

struct ForeignFeePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var card: CreditCard
    @FocusState private var isFocused: Bool

    @State private var valueText: String

    private var defaultRate: Double? {
        CardDatabase.getCard(id: card.templateID ?? "")?.foreignTransactionFeeRate
    }

    private var parsedValue: Double { Double(valueText) ?? 0 }
    private var parsedRate: Double? { parsedValue > 0 ? parsedValue / 100.0 : nil }
    private var isDefault: Bool { parsedRate == defaultRate }

    private var defaultDisplayValue: String {
        guard let r = defaultRate, r > 0 else { return "None" }
        return "\(Self.format(r))%"
    }

    private static func format(_ rate: Double?) -> String {
        guard let r = rate, r > 0 else { return "0" }
        let pct = r * 100
        return pct.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", pct)
            : String(format: "%.2f", pct)
    }

    init(card: CreditCard) {
        self.card = card
        _valueText = State(initialValue: Self.format(card.foreignTransactionFeeRate))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    inputSection
                    Spacer(minLength: 32)
                }
                .padding()
            }
            .background(Color.churOffWhite)
            .navigationTitle("Foreign Transaction Fee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let newRate = parsedRate
                        card.hasForeignTransactionFee = parsedValue > 0
                        card.foreignTransactionFeeRate = newRate
                        card.hasCustomForeignFee = newRate != defaultRate
                        dismiss()
                    }
                    .font(.churRowText())
                    .fontWeight(.bold)
                    .foregroundStyle(Color.churOlive)
                }
            }
        }
        .presentationDetents([.medium,.large])
        .presentationDragIndicator(.visible)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("🌍").font(.churBigTitle1())
            Text("Override the default foreign transaction fee for this card.")
                .font(.churCaptionRegular())
                .foregroundStyle(Color.churMediumGray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FOREIGN TRANSACTION FEE")
                .font(.churSmallBold())
                .foregroundStyle(Color.churOlive)
                .tracking(0.5)

            VStack(spacing: 0) {
                HStack {
                    Text("Rate")
                        .font(.churRowText())
                        .foregroundStyle(Color.churDarkGray)
                    Spacer()
                    HStack(spacing: 2) {
                        TextField("0", text: $valueText)
                            .keyboardType(.decimalPad)
                            .focused($isFocused)
                            .multilineTextAlignment(.trailing)
                            .font(.churRowText())
                            .foregroundStyle(Color.churOlive)
                            .frame(width: 70)
                        Text("%")
                            .font(.churRowText())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)

                if !isDefault {
                    Divider().padding(.horizontal, 16).opacity(0.5)

                    Button {
                        let r = defaultRate ?? 0
                        card.hasForeignTransactionFee = r > 0
                        card.foreignTransactionFeeRate = r > 0 ? r : nil
                        card.hasCustomForeignFee = false
                        valueText = Self.format(defaultRate)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise").font(.churSmall())
                            Text("Reset to default (\(defaultDisplayValue))").font(.churSmall())
                        }
                        .foregroundStyle(Color.churWarning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }
}
