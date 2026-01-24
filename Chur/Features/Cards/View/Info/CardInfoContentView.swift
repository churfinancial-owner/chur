//
//  CardInfoContentView.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import SwiftUI
import SwiftData

struct CardInfoContentView: View {
    let card: CreditCard
    
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [SpendingCategory]
    @Query private var users: [User]

    @State private var activeSheet: ActiveSheet?
    @State private var dateRefreshTick = 0
    
    // Internal Sheet tracking
    enum ActiveSheet: String, Identifiable {
        case annualFee, approvedDate, foreignFee, pointValues, configurableRewards, boost, rewardPlan
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
                    showEffectiveRate: user?.showEffectiveRate ?? false,
                    dateRefreshTick: dateRefreshTick,
                    onConfigureTap: { activeSheet = .configurableRewards }
                )
                
                // SECTION 2: CARD DETAILS
                CardDetailsSection(
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
        .onReceive(NotificationCenter.default.publisher(for: .currentDateDidChange)) { _ in
            dateRefreshTick += 1
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .timeTravelDateChanged)) { _ in
            dateRefreshTick += 1
        }
        #endif
    }
}
