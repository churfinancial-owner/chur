//
//  MapMerchantPopup.swift
//  Chur
//
//  Created by Pak Ho on 3/30/26.
//

import SwiftUI
import SwiftData

struct MerchantDetailSheet: View {
    @Environment(\.openURL) private var openURL

    @State private var viewModel: MerchantDetailViewModel
    @State private var showFormula = false
    #if DEBUG
    @State private var showingCategoryDetail = false
    #endif

    init(merchant: NearbyMerchant, category: SpendingCategory, cards: [CreditCard], allCategories: [SpendingCategory], boostEnrollments: [String: String], channel: String = "in_store") {
        _viewModel = State(initialValue: MerchantDetailViewModel(
            merchant: merchant, category: category, cards: cards,
            allCategories: allCategories, boostEnrollments: boostEnrollments, channel: channel
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection

                // The cards themselves bite into the sage — the first one's
                // rounded corners and shadow land on colour, which is where the
                // contrast comes from.
                RecommendationStackView(
                    bestCardSummary: viewModel.bestCardSummary,
                    otherCardRates: viewModel.otherCardRates,
                    cards: viewModel.cards,
                    showFormula: showFormula
                )
                #if DEBUG
                .onTapGesture { showingCategoryDetail = true }
                .sheet(isPresented: $showingCategoryDetail) { debugCalculator }
                #endif
                .popupHeroOverlap()

                Spacer(minLength: 40)
            }
        }
        .background(Color.churOffWhite)
    }

    // MARK: - Header

    private var headerSection: some View {
        PopupHeroHeader {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        HeaderCapsuleBubble(
                            text: viewModel.channel == "online" ? AppLocale.string("Online") : AppLocale.string("In-Store"),
                            icon: viewModel.channel == "online" ? "globe" : "storefront.fill"
                        )
                        if let region = viewModel.merchant.region {
                            HeaderCapsuleBubble(text: region, icon: "location.fill")
                        }
                        if let label = viewModel.categoryBubbleLabel {
                            HeaderCapsuleBubble(text: label, icon: "mappin.and.ellipse")
                        }
                    }
                }
                .popupHeroInset()

                Text(viewModel.merchant.name)
                    .popupHeroTitle()
                    .padding(.top, 10)

                HStack(spacing: 6) {
                    Text("Here's your best card here.")
                        .font(.churCaptionMedium())
                        .foregroundStyle(Color.churDarkGray)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showFormula.toggle() }
                    } label: {
                        Image(systemName: showFormula ? "info.circle.fill" : "info.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(showFormula ? Color.churSageDeep : Color.churMediumGray)
                    }
                }
                .padding(.top, 6)
                .popupHeroInset()

                // Inside the hero, not below it: the CTA is the hero's focal
                // point, and floating it over the sage is what the dark olive
                // pill is for.
                if viewModel.channel == "online", !viewModel.merchant.address.isEmpty {
                    shopNowButton
                        .padding(.top, 20)
                }
            }
        } avatar: {
            // Sized to the 55pt logo frame, not the watermark's old 80: the
            // emoji fallback is a Text and does not inherit the frame the way
            // the image does, so its size has to travel with the call site.
            MerchantIconView(iconName: viewModel.merchantIconName,
                             category: viewModel.category,
                             emojiFont: .system(size: 39))
        }
    }

    // MARK: - Shop Now

    private var shopNowButton: some View {
        let raw = viewModel.merchant.address
        let urlString = raw.hasPrefix("http") ? raw : "https://\(raw)"
        return Button {
            if let url = URL(string: urlString) { openURL(url) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Shop Now")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Color.churSageDeep, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    #if DEBUG
    private var debugCalculator: some View {
        CalculatorPopup(merchant: viewModel.merchant, category: viewModel.category, cards: viewModel.cards, allCategories: viewModel.allCategories, boostEnrollments: viewModel.boostEnrollments, channel: viewModel.channel)
    }
    #endif
}
