//
//  OnboardingRegionStep.swift
//  Chur
//
//  Step 3: Select region.
//  Aligned with OnboardingSignInStep UI and future-proofed for long lists.
//

import SwiftUI

struct OnboardingRegionStep: View {
    @Binding var selectedCountry: String
    let onContinue: () -> Void
    
    @State private var showAllRegions = false
    private let impact = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        ZStack {
            // Consistent background from SignInStep
            Color.churOffWhite.ignoresSafeArea()
            DotGridBackground().ignoresSafeArea().opacity(0.05)
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(minHeight: 24, maxHeight: 80)

                // Hero Section
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.churOlive.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "globe.americas.fill")
                            .font(.churBigTitle())
                            .foregroundStyle(Color.churOlive)
                    }

                    VStack(spacing: 8) {
                        Text("Where are you based?")
                            .font(.churTitle())
                            .foregroundStyle(Color.churDarkGray)

                        Text("We'll tailor your rewards and card suggestions to your local market.")
                            .font(.churRowTextRegular())
                            .foregroundStyle(Color.churMediumGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }

                Spacer().frame(height: 48)

                // Selection Area
                VStack(spacing: 16) {
                    let allRegions = RegionDatabase.activeRegions
                    let hasMultipleRegions = allRegions.count > 1

                    // Selected / recommended region card
                    if hasMultipleRegions {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SUGGESTED FOR YOU")
                                .font(.churMicroBold())
                                .foregroundStyle(Color.churMediumGray)
                                .padding(.leading, 8)

                            if let region = allRegions.first(where: { $0.id == selectedCountry }) {
                                regionCard(flag: region.flag, name: region.name, code: region.id, isRecommended: true)
                            }
                        }
                    } else {
                        if let region = allRegions.first(where: { $0.id == selectedCountry }) ?? allRegions.first {
                            regionCard(flag: region.flag, name: region.name, code: region.id, isRecommended: false)
                        }
                    }

                    // "Choose a different region" dropdown — only when multiple options exist
                    if hasMultipleRegions {
                        VStack(spacing: 12) {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showAllRegions.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("Choose a different region")
                                        .font(.churRowTextMedium())
                                        .foregroundStyle(Color.churOlive)
                                    Image(systemName: "chevron.down")
                                        .font(.churSmallBold())
                                        .foregroundStyle(Color.churOlive)
                                        .rotationEffect(.degrees(showAllRegions ? 180 : 0))
                                }
                                .padding(.vertical, 4)
                            }

                            if showAllRegions {
                                ScrollView {
                                    LazyVStack(spacing: 12) {
                                        ForEach(allRegions.filter { $0.id != selectedCountry }) { region in
                                            regionCard(flag: region.flag, name: region.name, code: region.id, isRecommended: false)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .frame(maxHeight: 180)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }
                }
                .padding(.horizontal, 30)

                Spacer()

                // Continue Button (Aligned with main CTA style)
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
                        .shadow(color: Color.churOlive.opacity(0.2), radius: 8, y: 4)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            }
        }
    }

    private func regionCard(flag: String, name: String, code: String, isRecommended: Bool) -> some View {
        Button {
            impact.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedCountry = code
                if !isRecommended { showAllRegions = false }
            }
        } label: {
            HStack(spacing: 16) {
                Text(flag)
                    .font(.churTitle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.churHeadline())
                        .foregroundStyle(Color.churDarkGray)
                    if isRecommended {
                        Text("Based on your location")
                            .font(.churMicroBold())
                            .foregroundStyle(Color.churOlive)
                    }
                }

                Spacer()

                Image(systemName: selectedCountry == code ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selectedCountry == code ? Color.churOlive : Color.churLightGray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selectedCountry == code ? Color.churOlive : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

