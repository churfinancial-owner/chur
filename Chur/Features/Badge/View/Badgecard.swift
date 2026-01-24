//
//  BadgeCard.swift
//  ChurApp
//

import SwiftUI

struct BadgeCard: View {
    let badge: Badge
    let unlocked: Bool
    let tier: BadgeTier
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            // THE WINDOW
            if let onAction = onAction {
                Button(action: onAction) {
                    BadgeIcon(badge: badge, unlocked: unlocked, tier: tier)
                }
                .buttonStyle(.plain)
            } else {
                BadgeIcon(badge: badge, unlocked: unlocked, tier: tier)
            }
            
            // EXTERNAL LABELS & INDICATORS
            VStack(spacing: 8) {
                // 1. Indicators moved ABOVE the text
                HStack(spacing: 5) {
                    ForEach(1...3, id: \.self) { index in
                        Circle()
                            .fill(index <= (unlocked ? tier.rawValue : 0) ? Color.blue : Color.churLightGray.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }

                // 2. Text moved BELOW the dots
                Text(badge.displayName.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(unlocked ? Color.primary : Color.churMediumGray)
                    .tracking(0.5)
                    // 3. Max two lines and centered
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 100) // Helps trigger the wrap if the name is long
                    .fixedSize(horizontal: false, vertical: true) // Allow vertical growth
            }
        }
        .padding(.bottom, 10)
    }
}
