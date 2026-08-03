import SwiftUI

struct FeesTermsSection: View {
    let card: CreditCard
    @Binding var activeSheet: CardInfoContentView.ActiveSheet?

    var foreignFeeDisplay: String {
        if !card.hasForeignTransactionFee { return AppLocale.string("None") }
        return card.foreignTransactionFeeRate?.formatted(.percent.precision(.fractionLength(0...2))) ?? AppLocale.string("Yes")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardSectionHeader(title: AppLocale.string("FEES & TERMS"))
            VStack(spacing: 0) {
                DetailRow(label: AppLocale.string("Annual Fee"), value: "$\(card.annualFee)", isEditable: true) {
                    activeSheet = .annualFee
                }
                CardRowDivider()
                DetailRow(label: AppLocale.string("Foreign Transaction Fee"), value: foreignFeeDisplay, isEditable: true) {
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
