///
//  CardInfoContentView.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import SwiftUI
import SwiftData

// MARK: - Card Info Content View

struct CardInfoContentView: View {
    let card: CreditCard

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var newsService: NewsService
    @Query private var categories: [SpendingCategory]
    @Query private var users: [User]

    @State private var activeSheet: ActiveSheet?
    @State private var selectedNewsPost: SanityPost?
    @State private var dateRefreshTick = 0
    @StateObject private var locationManager = LocationManager()
    
    enum ActiveSheet: String, Identifiable {
        case annualFee, approvedDate, foreignFee, pointValues, configurableRewards, boost, rewardPlan
        case network, cardType
        case userNote
        var id: String { rawValue }
    }

    private var user: User? { users.first }
    private var boostMultiplier: Double {
        card.boostMultiplier(enrollments: user?.boostEnrollments ?? [:])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // SECTION 1: EARNING RATES
                EarningRatesSection(
                    card: card,
                    categories: categories,
                    boostMultiplier: boostMultiplier,
                    dateRefreshTick: dateRefreshTick,
                    user: user,
                    currentRegionCodeOverride: locationManager.isoCountryCode,
                    onConfigureTap: { activeSheet = .configurableRewards }
                )

                // SECTION 2: REWARD SETUP
                RewardSetupSection(
                    card: card,
                    categories: categories,
                    user: user,
                    activeSheet: $activeSheet
                )

            }
            .padding()
        }
        .background(Color.churOffWhite)
        .sheet(item: $activeSheet) { sheet in
            CardInfoSheetPresenter(sheet: sheet, card: card)
        }
        .sheet(item: $selectedNewsPost) { post in
            NewsDetailPopup(post: post, allPosts: newsService.posts)
        }
        .onReceive(NotificationCenter.default.publisher(for: .currentDateDidChange)) { _ in
            dateRefreshTick += 1
        }
    }
}
