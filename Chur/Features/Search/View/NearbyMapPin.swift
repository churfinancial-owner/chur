//
//  Search_Map_Components.swift
//  Chur
//
//  Created by Pak Ho on 3/12/26.
//

import SwiftUI
import SwiftData
import MapKit


// MARK: - Nearby Map Pin (Updated for Icon Priority)

struct NearbyMapPin: View {
    let category: SpendingCategory?
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            if let category = category {
                // Uses the logic: Asset Catalog Icon > Emoji Fallback
                CategoryIconView(category: category, font: isSelected ? .churTitle2() : .churHeadline())
            } else {
                Text("📍").font(isSelected ? .churTitle2() : .churHeadline())
            }
        }
        .frame(width: isSelected ? 38 : 32, height: isSelected ? 38 : 32)
        .padding(6)
        .background(
            Circle()
                .fill(isSelected ? Color.churOlive : Color.white)
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
        )
        // Additional inner stroke if selected to make the logo pop
        .overlay(
            Circle()
                .stroke(Color.white.opacity(isSelected ? 0.5 : 0), lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}
