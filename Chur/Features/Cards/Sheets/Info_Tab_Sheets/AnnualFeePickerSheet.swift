import SwiftUI

struct AnnualFeePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var card: CreditCard
    @FocusState private var isFocused: Bool

    @State private var valueText: String

    private var defaultFee: Int {
        CardDatabase.getCard(id: card.templateID ?? "")?.annualFee ?? 0
    }
    private var parsedFee: Int { Int(valueText) ?? 0 }
    private var isDefault: Bool { parsedFee == defaultFee }

    init(card: CreditCard) {
        self.card = card
        _valueText = State(initialValue: "\(card.annualFee)")
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
            .navigationTitle("Annual Fee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let newFee = parsedFee
                        card.annualFee = newFee
                        card.hasCustomAnnualFee = newFee != defaultFee
                        dismiss()
                    }
                    .font(.churRowText())
                    .fontWeight(.bold)
                    .foregroundStyle(Color.churOlive)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("💳").font(.churBigTitle1())
            Text("Edit the fee if your card's annual fee differs from the default.")
                .font(.churCaptionRegular())
                .foregroundStyle(Color.churMediumGray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ANNUAL FEE")
                .font(.churSmallBold())
                .foregroundStyle(Color.churOlive)
                .tracking(0.5)

            VStack(spacing: 0) {
                HStack {
                    Text("Amount")
                        .font(.churRowText())
                        .foregroundStyle(Color.churDarkGray)
                    Spacer()
                    HStack(spacing: 2) {
                        Text("$")
                            .font(.churRowText())
                            .foregroundStyle(.secondary)
                        TextField("0", text: $valueText)
                            .keyboardType(.numberPad)
                            .focused($isFocused)
                            .multilineTextAlignment(.trailing)
                            .font(.churRowText())
                            .foregroundStyle(Color.churOlive)
                            .frame(width: 70)
                    }
                }
                .padding(16)

                if !isDefault {
                    Divider().padding(.horizontal, 16).opacity(0.5)

                    Button {
                        card.annualFee = defaultFee
                        card.hasCustomAnnualFee = false
                        valueText = "\(defaultFee)"
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise").font(.churSmall())
                            Text("Reset to default ($\(defaultFee))").font(.churSmall())
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
