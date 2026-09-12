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
    
    /// Which sheet is up, and anything it needs to open on.
    ///
    /// The payload rides on the case rather than a second `@State` set in the
    /// same action: SwiftUI can build a sheet's content from the view snapshot
    /// taken before that companion state landed, so the sheet opened with a
    /// stale — often nil — value. It presented correctly often enough to look
    /// intermittent. See the `ChurMenuRow` note in `CLAUDE.md` for the same
    /// hazard with a row that opens a second sheet.
    enum ActiveSheet: Identifiable {
        case annualFee, approvedDate, foreignFee, pointValues, configurableRewards, rewardPlan
        case network, cardType
        case userNote
        case cardStatus
        /// The boost program to edit.
        case boost(programID: String)
        /// The reward program to open the transfer sheet on.
        case transferPartners(programName: String)

        var id: String {
            switch self {
            case .annualFee:                     return "annualFee"
            case .approvedDate:                  return "approvedDate"
            case .foreignFee:                    return "foreignFee"
            case .pointValues:                   return "pointValues"
            case .configurableRewards:           return "configurableRewards"
            case .rewardPlan:                    return "rewardPlan"
            case .network:                       return "network"
            case .cardType:                      return "cardType"
            case .userNote:                      return "userNote"
            case .cardStatus:                    return "cardStatus"
            case .boost(let programID):          return "boost:\(programID)"
            case .transferPartners(let program): return "transferPartners:\(program)"
            }
        }
    }

    private var user: User? { users.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // SECTION 1: EARNING RATES
                EarningRatesSection(
                    card: card,
                    categories: categories,
                    enrollments: user?.boostEnrollments ?? [:],
                    dateRefreshTick: dateRefreshTick,
                    user: user,
                    currentRegionCodeOverride: locationManager.isoCountryCode,
                    onConfigureTap: { activeSheet = .configurableRewards }
                )

                // SECTION 2: BONUS PROGRAMS (earning layers, P1f) — only when the card has any
                BoostProgramsSection(
                    card: card,
                    categories: categories,
                    user: user,
                    activeSheet: $activeSheet
                )

                // SECTION 3: REWARD SETUP
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
