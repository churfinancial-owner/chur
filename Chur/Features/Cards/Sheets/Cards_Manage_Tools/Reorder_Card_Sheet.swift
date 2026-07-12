import SwiftUI
import SwiftData

struct CardOrderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var user: User
    let cards: [CreditCard]
    
    @State private var cardOrder: [String]
    @State private var cardToDelete: CreditCard? = nil
    @State private var showDeleteConfirmation = false
    
    // Sorting State
    @State private var currentSort: SortCriteria? = nil
    @State private var isAscending: Bool = true
    
    enum SortCriteria {
        case name, issuer, annualFee, approved
    }
    
    init(user: User, cards: [CreditCard]) {
        self.user = user
        self.cards = cards
        
        var initialOrder = user.cardDisplayOrder
        if initialOrder.isEmpty {
            initialOrder = cards.map { $0.id }
        } else {
            for card in cards {
                if !initialOrder.contains(card.id) {
                    initialOrder.append(card.id)
                }
            }
        }
        _cardOrder = State(initialValue: initialOrder)
    }
    
    var sortedCards: [CreditCard] {
        let cardMap = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        return cardOrder.compactMap { cardMap[$0] }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Header
                VStack(spacing: 8) {
                    Text("Reorder Cards")
                        .font(.churTitle())
                        .foregroundStyle(Color.churDarkGray)
                }
                .padding(.top, 8)
                .padding(.bottom, 12) // Slightly reduced padding for a tighter look
                
                // MARK: - List (Restored .reversed() logic)
                List {
                    let displayedCards = Array(sortedCards.reversed())
                    
                    ForEach(Array(displayedCards.enumerated()), id: \.element.id) { index, card in
                        cardRow(card, isPrimary: index == 0)
                    }
                    .onMove { source, destination in
                        // Reversing IDs to move them in the "mirrored" state
                        var reversedIDs = Array(cardOrder.reversed())
                        reversedIDs.move(fromOffsets: source, toOffset: destination)
                        cardOrder = Array(reversedIDs.reversed())
                        
                        currentSort = nil
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .onDelete { offsets in
                        let reversedCards = Array(sortedCards.reversed())
                        if let index = offsets.first {
                            cardToDelete = reversedCards[index]
                            showDeleteConfirmation = true
                        }
                    }
                    .listRowBackground(Color.white)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.churOffWhite)
                .environment(\.editMode, .constant(.active))
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
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("Sort Options") {
                            sortButton(title: "Card Name", criteria: .name)
                            sortButton(title: "Issuer", criteria: .issuer)
                            sortButton(title: "Annual Fee", criteria: .annualFee)
                            sortButton(title: "Date Approved", criteria: .approved)
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down").foregroundStyle(Color.churOlive)
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveOrder()
                        dismiss()
                    }
                    .font(.churRowText())
                    .fontWeight(.bold)
                    .foregroundStyle(Color.churOlive)
                }
            }
            .alert("Delete Card?", isPresented: $showDeleteConfirmation, presenting: cardToDelete) { card in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { deleteCard(card) }
            } message: { card in
                Text("Are you sure you want to delete \(card.name)? This will remove all tracked benefits and rewards data.")
            }
        }
    }
    
    @ViewBuilder
    private func cardRow(_ card: CreditCard, isPrimary: Bool) -> some View {
        HStack(spacing: 12) {
            if let uiImage = UIImage(named: card.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text(card.name).font(.churRowText()).foregroundStyle(Color.churDarkGray)
                    if isPrimary {
                        Text("DEFAULT").font(.system(size: 8, weight: .bold)).foregroundStyle(.white).padding(.horizontal, 4).padding(.vertical, 2).background(Color.churOlive).clipShape(Capsule())
                    }
                }
                Text(card.issuer).font(.churSmall()).foregroundStyle(Color.churMediumGray)
            }
            Spacer()
        }.padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func sortButton(title: String, criteria: SortCriteria) -> some View {
        Button { applySort(criteria) } label: {
            HStack {
                Text(title)
                if currentSort == criteria {
                    Image(systemName: isAscending ? "chevron.up" : "chevron.down")
                }
            }
        }
    }
    
    private func applySort(_ criteria: SortCriteria) {
        if currentSort == criteria {
            isAscending.toggle()
        } else {
            currentSort = criteria
            isAscending = (criteria == .name || criteria == .issuer)
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            let sorted: [CreditCard]
            switch criteria {
            case .name:
                sorted = cards.sorted { isAscending ? $0.name > $1.name : $0.name < $1.name }
            case .issuer:
                sorted = cards.sorted { isAscending ? $0.issuer > $1.issuer : $0.issuer < $1.issuer }
            case .annualFee:
                sorted = cards.sorted { isAscending ? $0.annualFee > $1.annualFee : $0.annualFee < $1.annualFee }
            case .approved:
                sorted = cards.sorted { cardA, cardB in
                    let valA = (cardA.approvedYear * 100) + cardA.approvedMonth
                    let valB = (cardB.approvedYear * 100) + cardB.approvedMonth
                    return isAscending ? valA > valB : valA < valB
                }
            }
            cardOrder = sorted.map { $0.id }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func saveOrder() {
        user.cardDisplayOrder = cardOrder
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    private func deleteCard(_ card: CreditCard) {
        withAnimation {
            cardOrder.removeAll { $0 == card.id }
            user.cardDisplayOrder = cardOrder
            modelContext.delete(card)
            if cardOrder.isEmpty { dismiss(); return }
            let remainingCards = cards.filter { $0.id != card.id }
            let proposals = ProgramUpgradeDatabase.detectPendingChanges(cards: remainingCards)
            ProgramUpgradeDatabase.applyAll(proposals, wallet: remainingCards)
            try? modelContext.save()
        }
    }
}
