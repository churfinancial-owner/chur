//
//  HomeView.swift
//  Chur
//
//  Main home screen container that orchestrates the primary user experience:
//  - Displays curved gradient header with personalized greeting
//  - Shows nearby merchant recommendations with best card suggestions
//  - This Month recap, Expiring Soon preview, and Earning Power analysis
//  - News feed is currently hidden behind FeatureFlags.homeNewsFeedEnabled
//  - Passes user data, cards, and categories to child components
//
//  Created by Pak Ho on 1/22/26.
//
import SwiftUI
import SwiftData

// MARK: - Home View (Greeting + Nearby + Earning Power) WITH CURVED HEADER
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [CreditCard]
    @Query private var users: [User]
    @Query private var categories: [SpendingCategory]
    
    var onOpenSearch: (() -> Void)? = nil
    var initialNearbyMerchants: [NearbyMerchant] = []
    var currentUser: User? { users.first }
    
    private var currentDate: String {
            Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
        }
    
    @State private var userLocation: String = "Unknown"
    @State private var currentCountryCode: String?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 20) {
                        Color.clear.frame(height: 140)

                        // SECTION 2: Nearby Recommendations
                        NearbyRecommendationsSection(
                            cards: cards,
                            categories: categories,
                            boostEnrollments: currentUser?.boostEnrollments ?? [:],
                            initialMerchants: initialNearbyMerchants,
                            onOpenSearch: onOpenSearch,
                            onLocationResolved: { locationLabel, countryCode in
                                if let locationLabel, !locationLabel.isEmpty {
                                    userLocation = locationLabel
                                }
                                currentCountryCode = countryCode
                            }
                        )
                        // Trimmed from 200 to match the loaded card row's natural height (~170) —
                        // 200 was leaving dead space below the cards vs. the other sections.
                        .frame(minHeight: 170, alignment: .top)

                        // SECTION 3: News Feed (disabled for go-live, see FeatureFlags.homeNewsFeedEnabled)
                        if FeatureFlags.homeNewsFeedEnabled {
                            NewsFeedSection()
                                .frame(minHeight: 230, alignment: .top)
                        }

                        // SECTION 3b: This Month recap (reuses UserWalletSummaryView's stat styling + MonthDetailSheet)
                        MonthlyRecapHomeSection(cards: cards)

                        // SECTION 3c: Expiring Soon preview (reuses ExpiringBenefitsView's data + row styling)
                        ExpiringSoonHomeSection(cards: cards)

                        // SECTION 4: Earning Power
                        if let user = currentUser {
                            EarningPowerSection(
                                cards: cards,
                                user: user,
                                currentRegionCodeOverride: currentCountryCode
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, UIConstants.tabBarHeight)
                }
                .background(Color.churOffWhite)
                
                CurvedHeaderView(
                    userName: currentUser?.firstName ?? "there",
                    currentDate: currentDate,
                    waveStyle: .home
                )
            }
            .edgesIgnoringSafeArea(.top)
            .navigationBarHidden(true)
        }
    }
}
