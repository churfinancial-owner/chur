import SwiftUI

struct UserNoteSection: View {
    let card: CreditCard
    @Binding var activeSheet: CardInfoContentView.ActiveSheet?

    private var notePreview: String {
        if card.note.isEmpty { return AppLocale.string("Add a note...") }

        if card.note.count > 20 {
            return String(card.note.prefix(20)) + "..."
        }
        return card.note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardSectionHeader(title: AppLocale.string("YOUR TOOLS"))
            VStack(spacing: 0) {
                DetailRow(
                    label: AppLocale.string("Personal Note"),
                    value: notePreview,
                    isEditable: true
                ) {
                    activeSheet = .userNote
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
