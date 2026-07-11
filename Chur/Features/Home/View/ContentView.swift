import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var newsService = NewsService()
    @State private var selectedTab = 0
    @State private var searchTabMode: SearchMode = .online
    @State private var hasLoadedSearchTab = false
    @State private var hasScheduledInitialization = false
    @State private var cachedNearbyMerchants: [NearbyMerchant] = []
    @State private var reminderRouter = BenefitReminderRouter.shared
    @State private var reminderDeepLinkTarget: BenefitDeepLinkTarget?
    @Query private var users: [User]
    @Query private var cards: [CreditCard]
    @Query private var categories: [SpendingCategory]

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Main Content Switcher
            Group {
                switch selectedTab {
                case 0: HomeView(onOpenSearch: { searchTabMode = .map; selectedTab = 3 }, initialNearbyMerchants: cachedNearbyMerchants)
                case 1: UserDashboardView()
                case 2: CardsView()
                case 3: NearbyPlacesListView(initialMode: searchTabMode, onModeChange: { searchTabMode = $0 }, onMerchantsUpdated: { cachedNearbyMerchants = $0 })
                default: HomeView()
                }
            }
            .environmentObject(newsService)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // This pushes the content up so it doesn't stay behind the bar
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 60)
            }

            // 2. Custom Instagram-Style Menu Bar
            customInstagramMenuBar
        }
        .task { await newsService.fetchNewsIfNeeded() }
        .onAppear {
            scheduleInitialDataInitialization()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                uploadBackupOnBackground()
            }
            // Reconcile on both transitions: .background captures any usage
            // logged this session; .active clears reminders made stale
            // elsewhere (e.g. day changes, restored backups).
            if newPhase == .background || newPhase == .active {
                BenefitReminderScheduler.shared.requestReconcile(context: modelContext)
            }
        }
        .onAppear { consumePendingReminderTap() }
        .onChange(of: reminderRouter.pendingBenefitID) { _, _ in
            consumePendingReminderTap()
        }
        .sheet(item: $reminderDeepLinkTarget) { target in
            BenefitReminderDeepLinkSheet(benefit: target.benefit, card: target.card)
        }
    }

    /// Resolves a tapped expiry-reminder notification to its card + benefit
    /// and presents the detail sheet. Benefit IDs come from templates and can
    /// repeat across cards, so the card ID is matched first.
    private func consumePendingReminderTap() {
        guard let benefitID = reminderRouter.pendingBenefitID else { return }
        let cardID = reminderRouter.pendingCardID
        reminderRouter.clear()

        let candidates = cards.sorted { ($0.id == cardID ? 0 : 1) < ($1.id == cardID ? 0 : 1) }
        for card in candidates {
            if let benefit = card.benefits.first(where: { $0.id == benefitID }) {
                reminderDeepLinkTarget = BenefitDeepLinkTarget(card: card, benefit: benefit)
                return
            }
        }
    }

    private var customInstagramMenuBar: some View {
        VStack(spacing: 0) {
            // Thin separator line at the top of the bar
            Divider().background(Color.white.opacity(0.2))

            HStack {
                Spacer()
                tabButton(id: 0, activeIcon: "house.fill", inactiveIcon: "house")
                Spacer()
                tabButton(id: 1, activeIcon: "person.crop.circle.fill", inactiveIcon: "person.crop.circle")
                Spacer()
                tabButton(id: 2, activeIcon: "creditcard.rewards.fill", inactiveIcon: "creditcard.rewards")
                Spacer()
                tabButton(id: 3, activeIcon: "sparkle.magnifyingglass", inactiveIcon: "magnifyingglass")
                Spacer()
            }
            .padding(.top, 15)
            .padding(.bottom, 5) // Extra padding for the iPhone home indicator area
        }
        .background(.ultraThinMaterial.opacity(0.9)) // Professional blur
        .ignoresSafeArea(edges: .bottom) // This makes it sit flush at the very bottom
    }

    private func tabButton(id: Int, activeIcon: String, inactiveIcon: String) -> some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = id
            }
        } label: {
            Image(systemName: selectedTab == id ? activeIcon : inactiveIcon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(selectedTab == id ? .churOlive : .churDarkGray.opacity(0.7))
        }
    }
    
    // ... Keep your existing Data Initialization functions below ...


    private func uploadBackupOnBackground() {
        guard let user = users.first, !user.googleUserID.isEmpty else { return }
        let backup = ChurBackup.snapshot(of: user, cards: cards)
        Task {
            try? await CloudSyncManager.shared.uploadBackup(backup)
        }
    }

    private func scheduleInitialDataInitialization() {
        guard !hasScheduledInitialization else { return }
        hasScheduledInitialization = true

        // Let first frame render before running first-launch setup work.
        Task(priority: .utility) {
            await Task.yield()
            await MainActor.run {
                initializeAppDataIfNeeded()
            }
        }
    }

    private func initializeAppDataIfNeeded() {
        // Always load categories if empty (onboarding may have created the user already)
        if TestDataConfiguration.loadSeedCategories && categories.isEmpty {
            SeedDataLoader.loadCategories(into: modelContext)
        }
        
        // Sync categories with latest bundle templates (add/update/deactivate)
        CategorySyncService.syncCategories(modelContext: modelContext)
        
        // Repair cards whose country was not persisted from the template
        repairCardCountryIfNeeded()
        
        // Sync persisted wallet cards with latest templates (rates, benefits, metadata)
        CardSyncService.syncWalletCards(modelContext: modelContext)
        
        // Only create test user if database is empty
        guard users.isEmpty else { return }
        
        // Create test user (if enabled)
        if TestDataConfiguration.enableTestUser {
            let testUser = User(
                firstName: TestDataConfiguration.TestUser.firstName,
                email: TestDataConfiguration.TestUser.email,
                appleUserID: TestDataConfiguration.TestUser.appleUserID
            )
            testUser.googleUserID = TestDataConfiguration.TestUser.googleUserID
            testUser.profileEmoji = TestDataConfiguration.TestUser.profileEmoji
            testUser.onboardingCompleted = TestDataConfiguration.TestUser.onboardingCompleted
            testUser.selectedCategories = TestDataConfiguration.TestUser.selectedCategories
            testUser.authProvider = TestDataConfiguration.TestUser.authProvider
            modelContext.insert(testUser)
            
            // Add starter cards (if any configured)
            for cardID in TestDataConfiguration.starterCardIDs {
                if let template = CardDatabase.getCard(id: cardID) {
                    let newCard = template.toCreditCard(modelContext: modelContext)
                    testUser.cardDisplayOrder.append(newCard.id)
                }
            }
        }
        
        // Save everything
        do {
            try modelContext.save()
        } catch {
            if TestDataConfiguration.enableDiagnosticLogging {
                print("❌ Failed to save initial data: \(error)")
            }
        }
    }
    
    /// One-time fix: cards created before the country-passthrough fix defaulted to "US".
    /// Look up each card's template and correct the country if it differs.
    private func repairCardCountryIfNeeded() {
        var didRepair = false
        for card in cards {
            guard let templateID = card.templateID,
                  let template = CardDatabase.getCard(id: templateID) else { continue }
            if card.country != template.country {
                card.country = template.country
                didRepair = true
            }
        }
        if didRepair {
            try? modelContext.save()
        }
    }
    
}
