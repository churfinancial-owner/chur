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
                if viewModel.channel == "online", !viewModel.merchant.address.isEmpty {
                    shopNowButton
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                }
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
                .padding(.top, 24)
                Spacer(minLength: 40)
            }
        }
        .background(Color.churOffWhite)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    HeaderCapsuleBubble(
                        text: viewModel.channel == "online" ? "Online" : "In-Store",
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
            .padding(.trailing, 110)

            Text(viewModel.merchant.name)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.churDarkGray)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.top, 10)
                .padding(.trailing, 110)

            HStack(spacing: 6) {
                Text("Here's your best card here.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.churMediumGray)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showFormula.toggle() }
                } label: {
                    Image(systemName: showFormula ? "info.circle.fill" : "info.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(showFormula ? Color.churOlive : Color.churMediumGray)
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 36)
        .padding(.bottom, 10)
        .overlay(alignment: .topTrailing) {
            PopupHeaderWatermark(categoryID: viewModel.category.id) {
                MerchantIconView(iconName: viewModel.merchantIconName, category: viewModel.category)
                    .frame(width: 80, height: 80)
                    .opacity(1)
            }
        }
        .clipped()
        .background(Color.churOffWhite)
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
            .padding(.horizontal, 32)
            .padding(.vertical, 18)
            .background(Color.churOlive, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    #if DEBUG
    private var debugCalculator: some View {
        CalculatorPopup(merchant: viewModel.merchant, category: viewModel.category, cards: viewModel.cards, allCategories: viewModel.allCategories, boostEnrollments: viewModel.boostEnrollments, channel: viewModel.channel)
    }
    #endif
}
