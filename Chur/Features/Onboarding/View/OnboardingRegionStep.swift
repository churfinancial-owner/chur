//
//  OnboardingRegionStep.swift
//  Chur
//
//  Step 3: Select region (US or HK).
//

import SwiftUI

struct OnboardingRegionStep: View {
    @Binding var selectedCountry: String
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "globe.americas.fill")
                    .font(.churBigTitle1())
                    .foregroundStyle(Color.churOlive)

                Text("Where are you based?")
                    .font(.churTitle())
                    .foregroundStyle(Color.churDarkGray)

                Text("We'll show you the right cards and rewards for your region.")
                    .font(.churRowTextRegular())
                    .foregroundStyle(Color.churMediumGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
                .frame(height: 40)

            // Region cards
            VStack(spacing: 16) {
                ForEach(RegionDatabase.activeRegions) { region in
                    regionCard(flag: region.flag, name: region.name, code: region.id)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue button
            Button {
                onContinue()
            } label: {
                Text("Continue")
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

    private func regionCard(flag: String, name: String, code: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedCountry = code
            }
        } label: {
            HStack(spacing: 16) {
                Text(flag)
                    .font(.churHero())

                Text(name)
                    .font(.churHeadline())
                    .foregroundStyle(Color.churDarkGray)

                Spacer()

                Image(systemName: selectedCountry == code ? "checkmark.circle.fill" : "circle")
                    .font(.churTitle2())
                    .foregroundStyle(selectedCountry == code ? Color.churOlive : Color.churLightGray)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                selectedCountry == code ? Color.churOlive : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
