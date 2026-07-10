//
//  OnboardingProgressIndicator.swift
//  Chur
//
//  Progress dots for the 5-step onboarding flow.
//

import SwiftUI

struct OnboardingProgressIndicator: View {
    let totalSteps: Int
    let currentStep: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? Color.churOlive : Color.churLightGray)
                    .frame(width: 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentStep)
            }
        }
    }
}

// MARK: - Shared Onboarding Background

/// Uniform olive dot grid — used as a subtle texture across onboarding steps.
struct DotGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 24
            let dotRadius: CGFloat = 1
            let cols = Int(size.width / spacing) + 2
            let rows = Int(size.height / spacing) + 2
            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing
                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius,
                                     width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(Color.churOlive.opacity(0.15)))
                }
            }
        }
    }
}
