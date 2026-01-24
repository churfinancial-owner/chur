import SwiftUI
import SwiftData

struct UserDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = UserDashboardViewModel()
    
    // 1. Data Source
    @Query private var cards: [CreditCard]
    @Query private var users: [User]
    
    @State private var showPerksPicker = false

    @State private var showingSettings = false
    @State private var showResetAlert = false
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date.current())
    @State private var selectedBadgeCategory: BadgeCategory? = nil
    
    #if DEBUG
    @State private var showingTimeTravel = false
    #endif
    
    var currentUser: User? { users.first }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 0) {
                        
                        // 0. Header Spacer
                        Color.clear.frame(height: 170)

                        // 1. Logic Banners
                        if viewModel.showResetSuccessBanner {
                            successBanner
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }

                        // --- Section 2: Profile ---
                        if let user = currentUser {
                            MemberInfoSection(
                                user: user,
                                onAvatarTap: { showingSettings = true }
                            )
                        }

                        // --- Divider 1→2 with Year Capsule ---
                        yearDivider()
                            .padding(.top, 20)

                        
                        // --- Section 3: Wallet Summary & Timeline ---
                        UserWalletSummaryView(cards: cards, selectedYear: $selectedYear)
                            .padding(.vertical, 32)
                            .background(Color("churOffWhite"))
                        
                        // --- Divider 3→4 with Perks Capsule ---
                        perksDivider()
                            .padding(.bottom, 16)
                        
                        // --- Section 4: Badges ---
                        BadgeCollectionSection(cards: cards, selectedCategory: nil)
                            .padding(.top, 16)
                            .padding(.bottom, 32)

                        
                        #if DEBUG
                        // --- Divider 4→5 (Coded) ---
                        sectionDivider()
                        
                        // --- Section 5: Developer Tools ---
                        DeveloperToolsSection(
                            showingTimeTravel: $showingTimeTravel,
                            showResetAlert: $showResetAlert,
                            onReloadJSONs: { viewModel.reloadAllJSONs(region: currentUser?.country ?? "US", modelContext: modelContext) },
                            onAddAllRegionCards: { viewModel.addAllRegionCards(modelContext: modelContext) }
                        )
                        .padding(.horizontal, 16)
                        #endif
                    }
                    .padding(.bottom, UIConstants.tabBarHeight)
                }
                .background(Color.churOffWhite)

                headerOverlay
            }
            .edgesIgnoringSafeArea(.top)
            .toolbar(.hidden, for: .navigationBar)
            
            // MARK: - Sheets & Alerts
            .sheet(isPresented: $showingSettings) {
                if let user = currentUser { SettingsView(user: user) }
            }
            #if DEBUG
            .sheet(isPresented: $showingTimeTravel) { TimeTravelSheet() }
            #endif
            .alert("Reset All Data?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    viewModel.resetAllData(modelContext: modelContext)
                }
            } message: {
                Text("This will erase everything and return to the welcome screen, as if the app was freshly installed.")
            }
        }
    }

    // MARK: - Local UI Components
    
    private func sectionDivider() -> some View {
        WaveDivider()
            .stroke(Color.churOliveLight, lineWidth: 5)
            .frame(height: 30)
            .padding(.horizontal, -10)
    }
    
    private var perksLabel: String {
        if let category = selectedBadgeCategory {
            return category.displayName
        }
        return "Your Perks"
    }
    
    private func perksDivider() -> some View {
        ZStack {
            WaveDivider()
                .stroke(Color.churOliveLight, lineWidth: 5)
                .frame(height: 30)
                .padding(.horizontal, -10)
            
            // Static Label instead of a Button
            HStack(spacing: 4) {
                Text("Your Perks")
                    .font(.churCaption())
            }
            .foregroundStyle(Color.churOlive)
            .frame(width: 160, height: 34)
            .background(Color.churOliveLight)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.churOlive.opacity(0.25), lineWidth: 1)
            )
        }
    }
    
    private func yearDivider() -> some View {
        ZStack {
            WaveDivider()
                .stroke(Color.churOliveLight, lineWidth: 5)
                .frame(height: 30)
                .padding(.horizontal, -10)
            
            HStack(spacing: 4) {
                Text("Your \(String(selectedYear))")
                    .font(.churCaption())
            }
            .foregroundStyle(Color.churOlive)
            .frame(width: 160, height: 34)
            .background(Color.churOliveLight)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.churOlive.opacity(0.25), lineWidth: 1)
            )
        }
    }
    
    private var successBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text("Reset complete. Seed data reloaded.")
                .font(.churFootnoteBold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.green)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var headerOverlay: some View {
        ZStack(alignment: .top) {
            CurvedHeaderBackgroundView(waveStyle: .user)
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 0) {
                    Text(currentUser?.firstName ?? "User")
                        .font(.churHero())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    Spacer()
                }
                .padding(.top, geometry.safeAreaInsets.top + 70)
                .padding(.horizontal, 10)
            }
        }
        .frame(height: 160)
    }
}
