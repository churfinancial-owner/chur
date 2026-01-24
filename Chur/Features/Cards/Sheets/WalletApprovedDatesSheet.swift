import SwiftUI

// MARK: - Wallet Approved Dates Sheet

struct WalletApprovedDatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let cards: [CreditCard]
    
    // Local editable copies: [card.id: (month, year)]
    @State private var edits: [String: (month: Int, year: Int)]
    
    private static let monthAbbreviations = [
        "1", "2", "3", "4", "5", "6",
        "7", "8", "9", "10", "11", "12"
    ]
    
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 20)...currentYear).reversed()
    }
    
    init(cards: [CreditCard]) {
        self.cards = cards
        var initial: [String: (month: Int, year: Int)] = [:]
        for card in cards {
            initial[card.id] = (month: card.approvedMonth, year: card.approvedYear)
        }
        _edits = State(initialValue: initial)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 0) {
                        Text("🗓️").font(.churBigTitle2())
                        Text("Set the approval date for each card in your wallet.")
                            .font(.churCaptionRegular())
                            .foregroundStyle(Color.churMediumGray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
                
                Section {
                    ForEach(cards, id: \.id) { card in
                        cardRow(card)
                    }
                }
            }
            .navigationTitle("Edit Approved Dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        for card in cards {
                            if let edit = edits[card.id] {
                                card.approvedMonth = edit.month
                                card.approvedYear = edit.year
                            }
                        }
                        dismiss()
                    }
                    .foregroundStyle(Color.churOlive)
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    @ViewBuilder
    private func cardRow(_ card: CreditCard) -> some View {
        let monthBinding = Binding<Int>(
            get: { edits[card.id]?.month ?? card.approvedMonth },
            set: { edits[card.id]?.month = $0 }
        )
        let yearBinding = Binding<Int>(
            get: { edits[card.id]?.year ?? card.approvedYear },
            set: { edits[card.id]?.year = $0 }
        )
        
        HStack(spacing: 12) {
            // 1. Card Image
            if let uiImage = UIImage(named: card.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            
            // 2. Card Info
            VStack(alignment: .leading, spacing: 0) {
                Text(card.name)
                    .font(.churRowText())
                    .foregroundStyle(Color.churDarkGray)
                Text(card.issuer)
                    .font(.churSmall())
                    .foregroundStyle(Color.churMediumGray)
            }
            
            Spacer()
            
            // 3. Compact Picker Group
            HStack(spacing: 4) { // Small gap between the boxes
                // Month Picker
                Picker("Month", selection: monthBinding) {
                    ForEach(1...12, id: \.self) { month in
                        Text("\(month)").tag(month)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 55) // Explicit width for the month box
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text("/")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.churMediumGray)
                
                // Year Picker
                Picker("Year", selection: yearBinding) {
                    ForEach(availableYears, id: \.self) { year in
                        Text("\(String(year).suffix(2))").tag(year)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 65) // Slightly wider for the year + chevron
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .tint(Color.churOlive) // Sets the color of the text inside the pickers
            .padding(.vertical, 6)
        }
    }
    
    @ViewBuilder
    private func dateLabel(text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.churRowTextMedium())
            .foregroundStyle(Color.churOlive)
            .frame(width: width, height: 32)
            .background(Color.churOlive.opacity(0.1)) // Subtle background highlight
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
}
