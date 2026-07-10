//
//  PerkToolComponents.swift
//  Chur
//
//  Shared components for Badge/tools perk detail sheets (lounge, hotel, car rental, etc.)
//

import SwiftUI

// MARK: - Shared Card Reference

struct PerkCardRef {
    let name: String
    let imageName: String
}

// MARK: - Card Chip

struct PerkCardChip: View {
    let card: PerkCardRef

    var body: some View {
        HStack(spacing: 8) {
            Image(card.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(card.name)
                .font(.churSmallBold())
                .foregroundStyle(Color.churDarkGray)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.churOffWhite)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
