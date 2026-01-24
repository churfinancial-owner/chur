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
