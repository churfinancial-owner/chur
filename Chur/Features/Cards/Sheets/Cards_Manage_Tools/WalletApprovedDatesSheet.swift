import SwiftUI

struct WalletApprovedDatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let cards: [CreditCard]
    
    // Local editable copies: [card.id: (month, day, year)]
    @State private var edits: [String: (month: Int, day: Int, year: Int)]
    
    init(cards: [CreditCard]) {
        self.cards = cards
        var initial: [String: (month: Int, day: Int, year: Int)] = [:]
        for card in cards {
            initial[card.id] = (month: card.approvedMonth, day: card.approvedDay, year: card.approvedYear)
        }
        _edits = State(initialValue: initial)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Standardized Chur Header
                Text("Approval Dates")
                    .font(.churTitle())
                    .foregroundStyle(Color.churDarkGray)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
                // MARK: - Refined List
                List {
                    Section {
                        ForEach(cards, id: \.id) { card in
                            cardRow(card)
                                .listRowBackground(Color.white) // High contrast for the rows
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden) // Makes churOffWhite visible
            }
            .background(Color.churOffWhite)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.red)
                        .fontWeight(.bold)
                        .font(.churRowText())
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("DONE") { // Uppercase matching your Add Card "DONE" button
                        saveChanges()
                    }
                    .font(.churRowText())
                    .fontWeight(.bold)
                    .foregroundStyle(Color.churOlive)
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func saveChanges() {
        for card in cards {
            if let edit = edits[card.id] {
                card.approvedMonth = edit.month
                card.approvedDay = edit.day
                card.approvedYear = edit.year
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
    
    @ViewBuilder
    private func cardRow(_ card: CreditCard) -> some View {
        let dateBinding = Binding<Date>(
            get: {
                let month = edits[card.id]?.month ?? card.approvedMonth
                let day = edits[card.id]?.day ?? card.approvedDay
                let year = edits[card.id]?.year ?? card.approvedYear
                return Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.month, .day, .year], from: newDate)
                edits[card.id] = (month: components.month ?? 1, day: components.day ?? 1, year: components.year ?? 2024)
            }
        )
        
        HStack(spacing: 12) {
            // Card Thumbnail
            if let uiImage = UIImage(named: card.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            }
            
            // Card Info
            VStack(alignment: .leading, spacing: 0) {
                Text(card.name)
                    .font(.churRowText())
                    .foregroundStyle(Color.churDarkGray)
                    .lineLimit(1)
                
                Text(card.issuer)
                    .font(.churSmall())
                    .foregroundStyle(Color.churMediumGray)
            }
            
            Spacer()
            
            DatePicker("", selection: dateBinding, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.churOlive) // Brands the calendar picker
                .scaleEffect(0.9)
        }
        .padding(.vertical, 4)
    }
}
