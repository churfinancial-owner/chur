//
//  FloatingRecommendationButton.swift
//  Chur
//
//  Created by Pak Ho on 4/3/26.
//

import SwiftUI

struct FloatingRecommendationButton: View {
    @State private var isAnimating = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "hand.thumbsup.fill").font(.system(size: 14, weight: .bold))
                Text("Offers").font(.churSectionHeader())
            }
            .foregroundStyle(Color.churDarkGray)
            .shadow(color: Color.churGold, radius: 1, x: 1, y: 1)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    Capsule().fill(LinearGradient(colors: [.yellow.opacity(0.6), .blue.opacity(0.6), .orange.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    Capsule().stroke(LinearGradient(colors: [.yellow.opacity(0.6), .blue.opacity(0.6), .orange.opacity(0.6)], startPoint: .leading, endPoint: .trailing), lineWidth: 1.5)
                }
                .shadow(color: Color.purple.opacity(0.25), radius: 10, x: 0, y: 5)
            )
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .offset(y: isAnimating ? -6 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { isAnimating = true }
        }
    }
}
