//
//  CardsView.swift
//  Chur
//

import SwiftUI
import SwiftData

struct CardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [CreditCard]
    @Query private var users: [User]
    @Query private var categories: [SpendingCategory]
    
    @State private var vm = CardsViewModel()
    @State private var showPopup = false

    var sortedCards: [CreditCard] {
        vm.getSortedCards(cards: cards, user: users.first)
    }

    // Logic to determine if the button should be visible
    private var hasRecommendations: Bool {
        let templates = RecommendationDatabase.getRecommendations(for: users.first?.country ?? "US")
        let results = CardRecommendationEngine.recommend(
            allTemplates: templates,
            userCards: cards,
            userStrategies: users.first?.strategyPreferences ?? [],
            userCountry: users.first?.country ?? "US",
            limit: 1
        )
        return !results.isEmpty
    }

    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(spacing: 8) {
                            Color.clear.frame(height: 140)
                            if cards.isEmpty {
                                CardsEmptyWalletView(showingAddCard: $vm.showingAddCard)
                            } else {
                                headerSection
                                CardCarouselView(width: geometry.size.width, sortedCards: sortedCards, viewModel: vm)
                                contentSection
                            }
                            Spacer(minLength: 50)
                        }
                    }
                    .contentShape(Rectangle())
                    .scrollDismissesKeyboard(.interactively)
                    .background(Color.churOffWhite)
                    .blur(radius: showPopup ? 5 : 0)
                    
                    CurvedHeaderBackgroundView(waveStyle: .cards)
                    titleOverlay(safeArea: geometry.safeAreaInsets.top)

                    // 2. Floating Action Button (Now Conditional)
                    if hasRecommendations {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                FloatingRecommendationButton {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        showPopup = true
                                    }
                                }
                                .padding(.trailing, 20)
                                .padding(.bottom, 55)
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // 3. Stacked Popup Overlay
                    if showPopup {
                        RecommendationStackOverlay(
                            isPresented: $showPopup,
                            userCards: cards,
                            allCategories: categories,
                            user: users.first
                        )
                    }
                }
                .edgesIgnoringSafeArea(.top)
                .navigationBarHidden(true)
                .sheet(isPresented: $vm.showingAddCard) { CardsView_AddCardView() }
                .sheet(item: $vm.cardToEdit) { CardsUserNoteSheet(card: $0) }
                .sheet(isPresented: $vm.showingCardOrder) {
                    if let user = users.first { CardOrderSheet(user: user, cards: sortedCards) }
                }
                .sheet(isPresented: $vm.showingApprovedDates) {
                    WalletApprovedDatesSheet(cards: sortedCards)
                }
                .sheet(isPresented: $vm.showingGoToCard) {
                    GoToCardSheet(sortedCards: sortedCards) { cardID in
                        vm.pendingScrollToCardID = cardID
                    }
                }
            }
        }
    }
}

// MARK: - View Components
private extension CardsView {
    func titleOverlay(safeArea: CGFloat) -> some View {
        GeometryReader { _ in
            VStack(alignment: .leading, spacing: 0) {
                Text("Cards")
                    .font(.churHero())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                Spacer()
            }
            .padding(.top, safeArea + 15)
            .padding(.horizontal, 10)
        }
        .frame(height: 160)
    }

    var headerSection: some View {
        HStack {
            Text("💳 YOUR WALLET (\(cards.count))")
                .font(.churHeadline())
                .foregroundStyle(Color.churOlive)
                .tracking(0.5)
            Spacer()
            HStack(spacing: 12) {
                addCardButton
                goToCardButton
                walletMenu
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    var addCardButton: some View {
        OliveIconButton(icon: "plus") { vm.showingAddCard = true }
    }

    var goToCardButton: some View {
        OliveIconButton(icon: "magnifyingglass") { vm.showingGoToCard = true }
    }

    var walletMenu: some View {
        Menu {
            Button { vm.showingCardOrder = true } label: {
                Label("Reorder/Delete", systemImage: "arrow.up.arrow.down")
            }
            Button { vm.showingApprovedDates = true } label: {
                Label("Edit Approved Dates", systemImage: "calendar")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.churOliveLight)
                    .frame(width: 32, height: 32)
                Image(systemName: "creditcard")
                    .font(.churImageMedium())
                    .foregroundStyle(.churDarkOlive)
            }
        }
    }
    
    var contentSection: some View {
        VStack(spacing: 0) {
            let selectedCard = sortedCards.first(where: { $0.id == vm.currentPage }) ?? sortedCards.first
            if let selectedCard {
                CardViewToggle(card: selectedCard, selectedTab: $vm.selectedTab)
                    .padding(.top, 4)
                
                cardDetailView(for: selectedCard)
                    .padding(.top, 12)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
            }
        }
        .padding(.vertical, 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.currentPage)
    }

    @ViewBuilder
    func cardDetailView(for card: CreditCard) -> some View {
        switch vm.selectedTab {
        case .benefits:
            BenefitsListContentView(card: card, selectedFrequency: $vm.selectedFrequency)
                .id("benefits-\(card.id)")
        case .cardinforewards:
            CardInfoContentView(card: card)
                .id("cardinforewards-\(card.id)")
        case .cardinfomationview:
            InfoListContentView(card: card)
                .id("cardinfomationview-\(card.id)")
        }
    }
}
