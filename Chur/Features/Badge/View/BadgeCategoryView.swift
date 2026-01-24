//
//  BadgeCategoryView.swift
//  Chur
//
//  Created by Pak Ho on 2/2/26.
//

import SwiftUI
import SwiftData

// MARK: - Badge Category View
struct BadgeCategoryView: View {
    let title: String
    let badges: [(badge: Badge, unlocked: Bool, tier: BadgeTier)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text(title)
                .font(.churCaption())
                .foregroundStyle(Color.churDarkGray)
                .padding(.horizontal)
            
            // Horizontal scrolling badges
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(badges, id: \.badge.id) { item in
                        BadgeIcon(badge: item.badge, unlocked: item.unlocked, tier: item.tier)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

