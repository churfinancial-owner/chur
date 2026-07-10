import SwiftUI

struct UserNoteSection: View {
    let card: CreditCard
    @Binding var activeSheet: CardInfoContentView.ActiveSheet?

    private var notePreview: String {
        if card.note.isEmpty { return "Add a note..." }
        
        if card.note.count > 20 {
            return String(card.note.prefix(20)) + "..."
        }
        return card.note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardSectionHeader(title: "YOUR TOOLS")
            VStack(spacing: 0) {
                DetailRow(
                    label: "Personal Note",
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
