//
//  RatePopupComponents.swift
//  Chur
//
//  Shared UI components used by category and merchant rate popup sheets.
//

import SwiftUI

// MARK: - CardRateSummary Display Helpers

extension CardRateSummary {
    var formattedRateText: String {
        let r = rate
        if r == floor(r) { return "\(Int(r))x" }
        return String(format: (r * 10).truncatingRemainder(dividingBy: 1) == 0 ? "%.1fx" : "%.2fx", r)
    }

    var effectivePctText: String {
        let eff = effectiveCashBackRate
        guard eff > 0 else { return "–" }
        let pct = eff * 100
        if pct.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(pct))%" }
        if (pct * 10).truncatingRemainder(dividingBy: 1) == 0 { return String(format: "%.1f%%", pct) }
        return String(format: "%.2f%%", pct)
    }

    func preferredRateMode(showEffectiveRate: Bool) -> RatePill.DisplayMode {
        if showEffectiveRate {
            if effectiveCashBackRate == 0 { return .empty }
            return effectiveCashBackRate < 0 ? .effectiveNegative : .effectivePositive
        }
        return rate > 0 ? .points : .empty
    }

    func preferredRateText(showEffectiveRate: Bool) -> String {
        showEffectiveRate ? effectiveRateDisplayString : formattedRateText
    }
}

// MARK: - Popup Header Watermark

struct PopupHeaderWatermark<Content: View>: View {
    let categoryID: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.categoryBadgeTint(for: categoryID))
                .frame(width: 140, height: 140)
            content()
        }
        .offset(x: 30, y: -16)
        .allowsHitTesting(false)
    }
}

// MARK: - Best Card Tile Content

struct PopupBestCardContent: View {
    let summary: CardRateSummary
    let card: CreditCard?
    let showFormula: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CardThumbnailView(card: card, width: 84, height: 54)
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.name)
                        .font(.churHeadline())
                        .foregroundStyle(Color.churDarkGray)
                        .lineLimit(1)
                    Text(card.map { IssuerDatabase.byName[$0.issuer]?.shortName ?? $0.issuer } ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.churMediumGray)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 14)

            BestCardStatStrip(
                rateText: summary.formattedRateText,
                effectivePctText: summary.effectivePctText,
                isEffectiveNegative: summary.effectiveCashBackRate < 0
            )

            if showFormula {
                RateFormulaRow(
                    formattedRate: summary.formattedRateText,
                    pointValueText: summary.pointValueDisplayString,
                    effectiveRateText: summary.effectiveRateDisplayString,
                    isNegative: summary.effectiveCashBackRate < 0
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Comparison Row

struct PopupComparisonRow: View {
    let summary: CardRateSummary
    let card: CreditCard?
    let showFormula: Bool

    @Environment(\.rewardDisplay) private var rewardDisplay

    var body: some View {
        HStack(spacing: 12) {
            CardThumbnailView(card: card, width: 60, height: 38)
                .shadow(color: .black.opacity(0.08), radius: 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.name)
                    .font(.churRowText())
                    .foregroundStyle(Color.churDarkGray)
                    .lineLimit(1)
                Text(card.map { IssuerDatabase.byName[$0.issuer]?.shortName ?? $0.issuer } ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.churMediumGray)
                    .lineLimit(1)
            }
            Spacer()
            if showFormula {
                HStack(spacing: 6) {
                    RatePill(text: summary.formattedRateText, displayMode: .points, size: .medium)
                    RatePill(
                        text: summary.effectiveRateDisplayString,
                        displayMode: summary.effectiveCashBackRate < 0 ? .effectiveNegative : .effectivePositive,
                        size: .medium
                    )
                }
            } else {
                RatePill(
                    text: summary.preferredRateText(showEffectiveRate: rewardDisplay.showEffectiveRate),
                    displayMode: summary.preferredRateMode(showEffectiveRate: rewardDisplay.showEffectiveRate),
                    size: .medium
                )
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Tile Container

struct RateTileContainer<Content: View>: View {
    let title: String
    let bannerColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.churBadgeBold())
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
        .background(Color.churTileWhiteBg.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }
}

// MARK: - Best Card Stat Strip

struct BestCardStatStrip: View {
    let rateText: String
    let effectivePctText: String
    var isEffectiveNegative: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            statCell(value: rateText, label: "CARD RATE", mode: .points)
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(width: 1)
                .padding(.vertical, 8)
            statCell(value: effectivePctText, label: "EFFECTIVE RATE", mode: isEffectiveNegative ? .effectiveNegative : .effectivePositive)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private func statCell(value: String, label: String, mode: RatePill.DisplayMode) -> some View {
        VStack(spacing: 5) {
            RatePill(text: value, displayMode: mode, size: .hero, showBackground: false)
            Text(label)
                .font(.churNanoBold())
                .kerning(0.8)
                .foregroundStyle(Color.churMediumGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - Rate Formula Row

struct RateFormulaRow: View {
    let formattedRate: String
    let pointValueText: String
    let effectiveRateText: String
    let isNegative: Bool

    var body: some View {
        HStack(spacing: 0) {
            rateColumn(label: "Card Rate", text: formattedRate, mode: .points)
            operatorLabel("×")
            rateColumn(label: "Point Value", text: pointValueText, mode: .programpointvalue)
            operatorLabel("=")
            rateColumn(label: "Effective Rate", text: effectiveRateText, mode: isNegative ? .effectiveNegative : .effectivePositive)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func rateColumn(label: String, text: String, mode: RatePill.DisplayMode) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.churBadgeMedium()).foregroundStyle(Color.churDarkGray)
            RatePill(text: text, displayMode: mode, size: .medium)
        }
    }

    private func operatorLabel(_ symbol: String) -> some View {
        Text(symbol)
            .font(.churFootnoteBold())
            .foregroundStyle(Color.churMediumGray)
            .padding(.horizontal, 6)
            .padding(.top, 14)
    }
}

// MARK: - Shared Recommendation Stack
//
// Used by both ParentCategoryParallaxSheet and MerchantDetailSheet to render
// the "BEST CARD TO USE" + "OTHER GREAT OPTIONS" sections.
// Owns its own isExpanded state so callers only need to pass data + showFormula.

struct RecommendationStackView: View {
    let bestCardSummary: CardRateSummary?
    let otherCardRates: [CardRateSummary]
    let cards: [CreditCard]
    let showFormula: Bool

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 20) {
            if let best = bestCardSummary {
                RateTileContainer(title: "BEST CARD TO USE", bannerColor: .churGold) {
                    PopupBestCardContent(
                        summary: best,
                        card: cards.first(where: { $0.name == best.name }),
                        showFormula: showFormula
                    )
                }
                if !otherCardRates.isEmpty {
                    RateTileContainer(title: "OTHER GREAT OPTIONS", bannerColor: .churMediumGray) {
                        comparisonContent
                    }
                }
            } else {
                EmptyStatePlaceholder(icon: "creditcard.trianglebadge.exclamationmark", title: "No matching cards", subtitle: "None of your cards earn rewards in this category.")
            }
        }
        .padding(.horizontal, 16)
    }

    private var comparisonContent: some View {
        Group {
            if isExpanded {
                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        ForEach(otherCardRates.prefix(5), id: \.name) { comparisonRow(for: $0) }
                    }.padding(16)
                    RateToggleButton(text: "Show Less", icon: "chevron.up") {
                        withAnimation(.spring(response: 0.3)) { isExpanded = false }
                    }
                }
            } else {
                Button { withAnimation(.spring(response: 0.3)) { isExpanded = true } } label: {
                    HStack {
                        HStack(spacing: 8) {
                            ForEach(otherCardRates.prefix(5), id: \.name) { summary in
                                CardThumbnailView(card: cards.first(where: { $0.name == summary.name }), width: 36, height: 22)
                                    .shadow(color: .black.opacity(0.1), radius: 2)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.churMediumGray)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 20)
                }
            }
        }.transition(.opacity)
    }

    private func comparisonRow(for summary: CardRateSummary) -> some View {
        PopupComparisonRow(
            summary: summary,
            card: cards.first(where: { $0.name == summary.name }),
            showFormula: showFormula
        )
    }
}

// MARK: - Toggle Button

struct RateToggleButton: View {
    let text: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack { Text(text); Image(systemName: icon) }
                .font(.churSmallBold())
                .foregroundStyle(Color.churMediumGray)
                .padding(.bottom, 16)
        }
    }
}

// MARK: - Header Capsule Bubble

struct HeaderCapsuleBubble: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.churBadge())
            Text(text)
                .font(.churMicroBold())
        }
        .foregroundStyle(Color.churDarkGray)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.churOlive.opacity(0.45))
        .clipShape(Capsule())
    }
}

//  MARK: - MerchantPopup_Components

import SwiftUI

struct CardThumbnailView: View {
    let card: CreditCard?
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        if let card, let uiImage = UIImage(named: card.imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else if let card {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.cardColor(for: card.issuer))
                .frame(width: width, height: height)
                .overlay {
                    Text(card.issuer.prefix(2).uppercased())
                        .font(.system(size: width > 70 ? 22 : 14, weight: .black))
                        .foregroundStyle(.white)
                }
        }
    }
}

// MARK: - Merchant Icon View

/// Displays a merchant's brand icon if available, otherwise falls back to the category icon/emoji.
/// Uses `.scaledToFit()` so wide wordmark logos (Amazon, Costco, etc.) are fully visible.
struct MerchantIconView: View {
    let iconName: String?
    let category: SpendingCategory?
    
    var body: some View {
        if let iconName, let uiImage = UIImage(named: iconName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else if let category {
            CategoryIconView(category: category, font: .system(size: 30))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Image(systemName: "storefront")
                .font(.churBigTitle4())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
