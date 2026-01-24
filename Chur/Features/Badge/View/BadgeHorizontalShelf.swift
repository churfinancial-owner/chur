//
//  BadgeHorizontalShelf.swift
//  Chur
//
//  Created by Pak Ho on 3/9/26.
//

import SwiftUI

struct BadgeHorizontalShelf: View {
    let cards: [CreditCard]
    let selectedCategory: BadgeCategory?
    var onExpertAction: () -> Void
    var onLoungeAction: () -> Void = {}
    var onHotelStatusAction: () -> Void = {}
    var onTrustedTravelerAction: () -> Void = {}
    var onCarRentalAction: () -> Void = {}
    var onCouponingAction: () -> Void = {}
    var onCellPhoneProtectionAction: () -> Void = {}
    var onAutoRentalCoverageAction: () -> Void = {}

    private var badges: [Badge] {
        if let category = selectedCategory {
            return BadgeDatabase.getBadges(for: category)
        }
        // All badges ordered: Lifestyle → Travel Access → Protections
        let categoryOrder: [BadgeCategory] = [.lifestyle, .travelAccess, .protections]
        return categoryOrder.flatMap { BadgeDatabase.getBadges(for: $0) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(badges, id: \.id) { badge in
                    let status = BadgeDetector.getBadgeStatus(badge: badge, cards: cards)
                    
                    BadgeCard(
                        badge: badge,
                        unlocked: status.isUnlocked,
                        tier: status.tier,
                        onAction: actionForBadge(badge.id)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func actionForBadge(_ id: String) -> (() -> Void)? {
        switch id {
        case "points_expert": return onExpertAction
        case "lounge_access": return onLoungeAction
        case "hotel_status": return onHotelStatusAction
        case "global_entry_like": return onTrustedTravelerAction
        case "carrental_status": return onCarRentalAction
        case "couponing": return onCouponingAction
        case "cell_phone_protection": return onCellPhoneProtectionAction
        case "auto_rental_coverage": return onAutoRentalCoverageAction
        default: return nil
        }
    }
}
