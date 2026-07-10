import SwiftUI
import SwiftData

struct UserDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = UserDashboardViewModel()
    
    // 1. Data Source
    @Query private var cards: [CreditCard]
    @Query private var users: [User]
    
    @State private var showingSettings = false
    @State private var showingPhotoPicker = false
    @State private var showResetAlert = false
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date.now)
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
                                onAvatarTap: { showingPhotoPicker = true }
                            )
                        }

                        // --- Divider 1→2 with Year Capsule ---
                        waveDivider(label: "Your \(selectedYear)")
                            .padding(.top, 20)

                        // --- Section 3: Wallet Summary & Timeline ---
                        UserWalletSummaryView(cards: cards, selectedYear: $selectedYear)
                            .padding(.vertical, 32)
                            .background(Color("churOffWhite"))
                        
                        // --- Divider 3→4 with Perks Capsule ---
                        waveDivider(label: "Your Perks")
                            .padding(.bottom, 16)
                        
                        // --- Section 4: Badges ---
                        BadgeCollectionSection(cards: cards, selectedCategory: nil)
                            .padding(.top, 16)
                            .padding(.bottom, 32)

                        // --- Divider 4→5 with Support Capsule ---
                        waveDivider(label: "Your Support")
                            .padding(.top, 16)
                            .padding(.bottom, 16)

                        // --- Section 5: Your Support ---
                        if let user = currentUser {
                            YourSupportSection(user: user, cards: cards)
                                .padding(.bottom, 32)
                        }

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
            .sheet(isPresented: $showingPhotoPicker) {
                if let user = currentUser { ProfilePhotoEditSheet(user: user) }
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
    
    private func waveDivider(label: String) -> some View {
        ZStack {
            WaveDivider()
                .stroke(Color.churOliveLight, lineWidth: 5)
                .frame(height: 30)
                .padding(.horizontal, -10)

            Text(label)
                .font(.churCaption())
                .foregroundStyle(Color.churOlive)
                .frame(width: 160, height: 34)
                .background(Color.churOliveLight)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.churOlive.opacity(0.25), lineWidth: 1))
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
                HStack(alignment: .top) {
                    // Title Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text(currentUser?.firstName ?? "User")
                            .font(.churHero())
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                    
                    Spacer()
                    
                    // MARK: - Settings Button
                    HStack(spacing: 8) {
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.churDarkGray)
                                .frame(width: 38, height: 38)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        }

                        // MARK: - Floating Developer Menu
                        #if DEBUG
                        Menu {
                        Button(action: { showingTimeTravel = true }) {
                            Label("Time Travel", systemImage: "clock.arrow.2.circlepath")
                        }
                        
                        Button(action: {
                            viewModel.reloadAllJSONs(region: currentUser?.country ?? "US", modelContext: modelContext)
                        }) {
                            Label("Reload JSONs", systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: {
                            viewModel.addAllRegionCards(modelContext: modelContext)
                        }) {
                            Label("Add All Region Cards", systemImage: "plus.square.on.square")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: { showResetAlert = true }) {
                            Label("Reset All Data", systemImage: "trash")
                        }
                    } label: {
                        // Airplane-window/Liquid-glass style badge
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                        .padding(.top, -8)
                        #endif
                    }
                    .padding(.top, -8)
                }
                .padding(.top, geometry.safeAreaInsets.top + 70)
                .padding(.horizontal, 16)
            }
        }
        .frame(height: 160)
    }
}
