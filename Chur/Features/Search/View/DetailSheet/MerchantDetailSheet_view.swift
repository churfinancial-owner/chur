//
//  MerchantDetailSheet.swift
//  Chur
//
//  Created by Pak Ho on 3/30/26.
//

import SwiftUI
import SwiftData

struct MerchantDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    
    @State private var viewModel: MerchantDetailViewModel
    @State private var isExpanded = false
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

    private var showEffectiveRate: Bool { users.first?.showEffectiveRate ?? false }

    /// Single pill text respecting user preference
    private func preferredRateText(for summary: CardRateSummary) -> String {
        showEffectiveRate
            ? summary.effectiveRateDisplayString
            : viewModel.formatRate(for: summary, showEffectiveRate: false)
    }

    /// Single pill mode respecting user preference
    private func preferredRateMode(for summary: CardRateSummary) -> RatePill.DisplayMode {
        if showEffectiveRate {
            if summary.effectiveCashBackRate == 0 { return .empty }
            return summary.effectiveCashBackRate < 0 ? .effectiveNegative : .effectivePositive
        }
        return summary.rate > 0 ? .points : .empty
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    merchantInfoSection.padding(.top, 8)
                    recommendationStack.padding(.top, 24)
                    Spacer(minLength: 40)
                }
            }
            .background(Color.churOffWhite)
            dismissButton
        }
    }

    // MARK: - Recommendation Stack
    private var recommendationStack: some View {
        VStack(spacing: 20) {
            if let best = viewModel.bestCardSummary {
                // 1. Best Card Section
                tileContainer(title: "BEST CARD TO USE", bannerColor: .churGold) {
                    bestCardContent(for: best)
                }
                #if DEBUG
                .onTapGesture { showingCategoryDetail = true }
                .sheet(isPresented: $showingCategoryDetail) { debugCalculator }
                #endif

                // 2. Comparison Section
                if !viewModel.otherCardRates.isEmpty {
                    tileContainer(title: "OTHER GREAT OPTIONS", bannerColor: .churMediumGray) {
                        comparisonContent
                    }
                }
            } else {
                noCardView
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - UI Shell (The "Cleanup" Magic)
    /// A generic container that ensures all sections look identical
    private func tileContainer<Content: View>(title: String, bannerColor: Color, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .kerning(1.2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(bannerColor)
                    .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 8))
                Spacer()
            }
            
            content()
        }
        .background(Color.churTiles)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - Internal Contents
    private func bestCardContent(for summary: CardRateSummary) -> some View {
        let card = viewModel.cards.first(where: { $0.name == summary.name })
        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                CardThumbnailView(card: card, width: 90, height: 58)
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.name).font(.churHeadline()).foregroundStyle(Color.churDarkGray).lineLimit(1)
                    Text(card.map { IssuerDatabase.byName[$0.issuer]?.shortName ?? $0.issuer } ?? "").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.churMediumGray)
                }
                Spacer()

                // Rate pill + info toggle
                HStack(spacing: 6) {
                    RatePill(text: preferredRateText(for: summary), displayMode: preferredRateMode(for: summary), size: .large)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showFormula.toggle() }
                    } label: {
                        Image(systemName: showFormula ? "info.circle.fill" : "info.circle")
                            .font(.churBody())
                            .foregroundStyle(showFormula ? Color.churOlive : Color.churMediumGray)
                    }
                }
            }

            // Formula row — only visible when info is tapped
            if showFormula {
                HStack(spacing: 0) {
                    rateColumn(label: "Card Rate", text: viewModel.formatRate(for: summary, showEffectiveRate: false), mode: .points)
                    formulaOperator("×")
                    rateColumn(label: "Point Value", text: summary.pointValueDisplayString, mode: .programpointvalue)
                    formulaOperator("=")
                    rateColumn(label: "Effective Rate", text: summary.effectiveRateDisplayString, mode: summary.effectiveCashBackRate < 0 ? .effectiveNegative : .effectivePositive)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 20)
    }

    private var comparisonContent: some View {
        Group {
            if isExpanded {
                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        ForEach(viewModel.otherCardRates.prefix(5), id: \.name) { comparisonRow(for: $0) }
                    }.padding(16)
                    
                    toggleButton(text: "Show Less", icon: "chevron.up", expanded: false)
                }
            } else {
                Button { withAnimation(.spring(response: 0.3)) { isExpanded = true } } label: {
                    HStack {
                        HStack(spacing: 8) {
                            ForEach(viewModel.otherCardRates.prefix(5), id: \.name) { summary in
                                CardThumbnailView(card: viewModel.cards.first(where: { $0.name == summary.name }), width: 36, height: 22)
                                    .shadow(color: .black.opacity(0.1), radius: 2)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.churMediumGray)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 20)
                }
            }
        }.transition(.opacity)
    }

    // MARK: - Reusable Small Helpers
    private func rateColumn(label: String, text: String, mode: RatePill.DisplayMode) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.churBadgeMedium()).foregroundStyle(Color.churDarkGray)
            RatePill(text: text, displayMode: mode, size: .medium)
        }
    }

    private func formulaOperator(_ symbol: String) -> some View {
        Text(symbol).font(.churFootnoteBold()).foregroundStyle(Color.churMediumGray).padding(.horizontal, 6).padding(.top, 14)
    }
    
    private func toggleButton(text: String, icon: String, expanded: Bool) -> some View {
        Button { withAnimation(.spring(response: 0.3)) { isExpanded = expanded } } label: {
            HStack { Text(text); Image(systemName: icon) }
                .font(.churSmallBold())
                .foregroundStyle(Color.churMediumGray).padding(.bottom, 16)
        }
    }

    // MARK: - Other View Parts (Unchanged but organized)
    private var headerSection: some View {
        PatternHeaderBanner(imageName: "HeaderPattern1") {
            MerchantIconView(iconName: viewModel.merchantIconName, category: viewModel.category)
        }
    }

    private var merchantInfoSection: some View {
        VStack(spacing: 12) {
            Text(viewModel.merchant.name)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.churDarkGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let region = viewModel.merchant.region {
                        capsuleBubble(text: region, icon: "location.fill")
                    }
                    capsuleBubble(
                        text: viewModel.channel == "online" ? "Online" : "In-Store",
                        icon: viewModel.channel == "online" ? "globe" : "storefront.fill"
                    )
                    if let label = viewModel.categoryBubbleLabel {
                        capsuleBubble(text: label, icon: "mappin.and.ellipse")
                    }
                }
                .padding(.horizontal, 16)
                .frame(minWidth: UIScreen.main.bounds.width, alignment: .center)
            }
        }
    }

    private func capsuleBubble(text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.churBadge())
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded)) // Smaller, punchier font
        }
        .foregroundStyle(Color.churDarkGray)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.churOlive.opacity(0.45)) 
        .clipShape(Capsule())
    }
    
    private func comparisonRow(for summary: CardRateSummary) -> some View {
        let card = viewModel.cards.first(where: { $0.name == summary.name })
        return HStack(spacing: 12) {
            CardThumbnailView(card: card, width: 60, height: 38).shadow(color: .black.opacity(0.08), radius: 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.name).font(.churRowText()).foregroundStyle(Color.churDarkGray).lineLimit(1)
                Text(card.map { IssuerDatabase.byName[$0.issuer]?.shortName ?? $0.issuer } ?? "").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.churMediumGray).lineLimit(1)
            }
            Spacer()
            if showFormula {
                // Info mode: show both card rate + effective rate
                HStack(spacing: 6) {
                    RatePill(text: viewModel.formatRate(for: summary, showEffectiveRate: false), displayMode: .points, size: .small)
                    RatePill(text: summary.effectiveRateDisplayString, displayMode: summary.effectiveCashBackRate < 0 ? .effectiveNegative : .effectivePositive, size: .small)
                }
            } else {
                // Default: single pill respecting user preference
                RatePill(text: preferredRateText(for: summary), displayMode: preferredRateMode(for: summary), size: .medium)
            }
        }
        .padding(12).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var dismissButton: some View { SheetDismissButton { dismiss() } }
    private var noCardView: some View { Text("No Matching Cards").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.churMediumGray).frame(maxWidth: .infinity).padding(20).background(RoundedRectangle(cornerRadius: 16).fill(Color.churTiles)) }
    
    #if DEBUG
    private var debugCalculator: some View {
        CalculatorPopup(merchant: viewModel.merchant, category: viewModel.category, cards: viewModel.cards, allCategories: viewModel.allCategories, boostEnrollments: viewModel.boostEnrollments, channel: viewModel.channel)
    }
    #endif
}
