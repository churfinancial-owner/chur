//
//  OnboardingWelcomeStep.swift
//  Chur
//
//  Step 1: Welcome screen with app branding and feature highlights.
//

import SwiftUI

struct OnboardingWelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App branding
            VStack(spacing: 12) {
                Text("Chur")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.churOlive)

                Text("Make every swipe count")
                    .font(.churHeadline())
                    .foregroundStyle(Color.churMediumGray)
            }

            Spacer()
                .frame(height: 48)

            // Feature highlights
            VStack(spacing: 20) {
                featureRow(
                    icon: "creditcard.fill",
                    title: "Track Your Cards",
                    description: "Keep all your credit cards and rewards in one place"
                )

                featureRow(
                    icon: "star.fill",
                    title: "Maximize Rewards",
                    description: "See which card earns the most for every purchase"
                )

                featureRow(
                    icon: "mappin.and.ellipse",
                    title: "Nearby Suggestions",
                    description: "Get card recommendations at places near you"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Get Started button
            Button {
                onContinue()
            } label: {
                Text("Get Started")
                    .font(.churHeadline())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.churOlive)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.churTitle2())
                .foregroundStyle(Color.churOlive)
                .frame(width: 44, height: 44)
                .background(Color.churOlive.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.churSectionHeader())
                    .foregroundStyle(Color.churDarkGray)

                Text(description)
                    .font(.churCaptionRegular())
                    .foregroundStyle(Color.churMediumGray)
            }

            Spacer()
        }
    }
}
