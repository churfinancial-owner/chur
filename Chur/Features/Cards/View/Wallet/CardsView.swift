//
//  CardsView.swift
//  Chur
//

import SwiftUI
import SwiftData

struct CardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CreditCard> { $0.status != "cancelled" }) private var cards: [CreditCard]
    @Query private var users: [User]
    @Query private var categories: [SpendingCategory]
    
    @State private var vm = CardsViewModel()
    @State private var showPopup = false
    @State private var reminderRouter = ReminderRouter.shared

    /// Nil except for a few seconds after a manual refresh. A pull that reports
    /// nothing is indistinguishable from a pull that did nothing.
    @State private var refreshStatus: ContentRefreshCoordinator.Result?

    /// The system's pull-to-refresh spinner is inside the ScrollView, so the
    /// 160pt header hides it. Without this, a refresh that takes a second looks
    /// like nothing happened at all.
    @State private var isRefreshing = false

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
                    // The user's only way to ask for new content. Everything else
                    // is automatic and silent, which leaves nothing to do when it
                    // hasn't worked — "pull down on your wallet" is an
                    // instruction support can actually give.
                    .refreshable { await pullToRefresh() }
                    .scrollDismissesKeyboard(.interactively)
                    .background(Color.churOffWhite)
                    .blur(radius: showPopup ? 5 : 0)
                    
                    CurvedHeaderBackgroundView(waveStyle: .cards)
                    titleOverlay(safeArea: geometry.safeAreaInsets.top)

                    // Anchored to the bottom, not the top. The header, its curve
                    // and the title overlay all occupy the top 160pt, and the
                    // system's own refresh spinner is already lost behind them —
                    // putting the status there means competing for the one strip
                    // of screen that is guaranteed to be busy.
                    VStack {
                        Spacer()
                        refreshStatusBanner
                            .padding(.bottom, 100)
                    }
                    .allowsHitTesting(false)

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
                .sheet(isPresented: $vm.showingCardHistory) {
                    CardHistorySheet()
                }
                .onAppear { consumePendingReminderScroll() }
                .onChange(of: reminderRouter.pendingScrollToCardID) { _, _ in
                    consumePendingReminderScroll()
                }
            }
        }
    }

    /// Picks up the card an annual fee reminder tap wants the wallet
    /// carousel scrolled to (ReminderRouter.pendingScrollToCardID), reusing
    /// the same scroll mechanism GoToCardSheet uses.
    private func consumePendingReminderScroll() {
        guard let cardID = reminderRouter.pendingScrollToCardID else { return }
        reminderRouter.pendingScrollToCardID = nil
        vm.pendingScrollToCardID = cardID
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

    @ViewBuilder
    private var refreshStatusBanner: some View {
        if isRefreshing || refreshStatus != nil {
            HStack(spacing: 6) {
                if isRefreshing {
                    ProgressView().scaleEffect(0.7).tint(.white)
                    Text("Checking for updates…")
                } else if let refreshStatus {
                    Image(systemName: refreshStatus == .failed ? "exclamationmark.triangle" : "checkmark.circle")
                    Text(refreshStatusText(refreshStatus))
                }
            }
            .font(.churCaption())
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(refreshStatus == .failed ? Color.churMediumGray : Color.churOlive)
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            )
            .transition(.opacity)
        }
    }

    private func refreshStatusText(_ result: ContentRefreshCoordinator.Result) -> String {
        switch result {
        case .updated: return String(localized: "Card details updated")
        case .alreadyCurrent: return String(localized: "Everything is up to date")
        case .failed: return String(localized: "Couldn't check for updates")
        }
    }

    /// Skips the 30-minute interval gate — a deliberate pull means "check now" —
    /// but not the version gate, so it costs one small manifest fetch when
    /// nothing has changed.
    private func pullToRefresh() async {
        #if DEBUG
        print("🔄 CardsView: pull-to-refresh fired")
        #endif
        withAnimation { isRefreshing = true }
        let result = await ContentRefreshCoordinator.refreshNow(modelContext: modelContext)

        withAnimation {
            isRefreshing = false
            refreshStatus = result
        }

        // Unstructured on purpose. `.refreshable` cancels its task as soon as
        // the gesture finishes, and a sleep in a cancelled task returns
        // instantly — which cleared the status in the same frame it appeared,
        // so the pill was drawn for one frame and never seen.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            withAnimation { refreshStatus = nil }
        }
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
        OliveRingIconButton(icon: "plus") { vm.showingAddCard = true }
    }

    var goToCardButton: some View {
        OliveRingIconButton(icon: "magnifyingglass") { vm.showingGoToCard = true }
    }

    var walletMenu: some View {
        Menu {
            Button { vm.showingCardOrder = true } label: {
                Label("Reorder/Delete", systemImage: "arrow.up.arrow.down")
            }
            Button { vm.showingApprovedDates = true } label: {
                Label("Edit Approved Dates", systemImage: "calendar")
            }
            Button { vm.showingCardHistory = true } label: {
                Label("Card History", systemImage: "clock.arrow.circlepath")
            }
        } label: {
            OliveRingIcon(icon: "creditcard")
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
