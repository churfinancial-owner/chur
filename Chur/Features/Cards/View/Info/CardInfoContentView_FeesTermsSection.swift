import SwiftUI

struct FeesTermsSection: View {
    let card: CreditCard
    @Binding var activeSheet: CardInfoContentView.ActiveSheet?

    var foreignFeeDisplay: String {
        if !card.hasForeignTransactionFee { return "None" }
        return card.foreignTransactionFeeRate?.formatted(.percent.precision(.fractionLength(0...2))) ?? "Yes"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardSectionHeader(title: "FEES & TERMS")
            VStack(spacing: 0) {
                DetailRow(label: "Annual Fee", value: "$\(card.annualFee)", isEditable: true) {
                    activeSheet = .annualFee
                }
                CardRowDivider()
                DetailRow(label: "Foreign Transaction Fee", value: foreignFeeDisplay, isEditable: true) {
                    activeSheet = .foreignFee
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
