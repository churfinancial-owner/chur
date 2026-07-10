//
//  Style.swift
//  Chur
//
//  Created by Pak Ho on 1/24/26.
//

import SwiftUI

// MARK: - Shared Gradients

extension Color {
    static let churGoldGradient = LinearGradient(
        colors: [Color.churGold, Color.churGold.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Squishy Button Style
struct SquishyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
