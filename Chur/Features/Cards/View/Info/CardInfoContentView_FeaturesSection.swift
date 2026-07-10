import SwiftUI

struct InfoListContentView: View {
    @Bindable var card: CreditCard
    
    @State private var activeSheet: CardInfoContentView.ActiveSheet?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CardInformationSection(card: card, activeSheet: $activeSheet)
                FeesTermsSection(card: card, activeSheet: $activeSheet)
                UserNoteSection(card: card, activeSheet: $activeSheet)
            }
            .padding()
        }
        .background(Color.churOffWhite)
        .sheet(item: $activeSheet) { sheet in
            CardInfoSheetPresenter(sheet: sheet, card: card)
        }
    }
}
