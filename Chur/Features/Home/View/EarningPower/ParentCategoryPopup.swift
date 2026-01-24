//
//  ParentCategoryParallaxSheet.swift
//  Chur
//
//  Created by Pak Ho on 1/25/26.
//

import SwiftUI
import SwiftData

struct ParentCategoryParallaxSheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: SpendingCategory
    let rate: Double
    let cards: [CreditCard]
    let allCategories: [SpendingCategory]
    let currentRegionCodeOverride: String?
    var headerLabel: String = "GENERAL CATEGORY"
    var showRelatedCategories: Bool = true

    @Query private var users: [User]
    @State private var isExpanded = false
    @State private var showFormula = false
    @State private var selectedChild: SpendingCategory? = nil

    private var boostEnrollments: [String: String] { users.first?.boostEnrollments ?? [:] }
    private var showEffectiveRate: Bool { users.first?.showEffectiveRate ?? false }
    private var earningPowerTravelModeEnabled: Bool { users.first?.earningPowerTravelModeEnabled ?? false }
    private var isAwayFromHomeRegion: Bool {
        guard let home = normalizedRegionCode(users.first?.country),
              let current = normalizedRegionCode(currentRegionCodeOverride ?? Locale.current.region?.identifier) else {
            return false
        }
        return home != current
    }
    private var effectiveTravelModeEnabled: Bool { earningPowerTravelModeEnabled && isAwayFromHomeRegion }

    private func normalizedRegionCode(_ code: String?) -> String? {
        guard let raw = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), !raw.isEmpty else {
            return nil
        }
        switch raw {
        case "PR", "VI", "GU", "AS", "MP":
            return "US"
        default:
            return raw
        }
    }

    // MARK: - Card Rate Calculator

    private var calculator: CardRateCalculator {
        CardRateCalculator(
            cards: cards,
            category: category,
            rate: rate,
            allCategories: allCategories,
            boostEnrollments: boostEnrollments,
            region: nil,
            channel: nil,
            allowPaymentMethodFallback: false,
            forceCrossBorder: effectiveTravelModeEnabled
        )
    }

    // MARK: - Child Categories

    private var childCategories: [SpendingCategory] {
        allCategories.filter { $0.parentCategoryID == category.id && $0.level == .child }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func calculator(for child: SpendingCategory) -> CardRateCalculator {
        CardRateCalculator(
            cards: cards,
            category: child,
            rate: 0,
            allCategories: allCategories,
            boostEnrollments: boostEnrollments,
            region: nil,
            channel: nil,
            allowPaymentMethodFallback: false,
            forceCrossBorder: effectiveTravelModeEnabled
        )
    }

    private func rateText(for child: SpendingCategory) -> String {
        let childRate = calculator(for: child).bestCard?.rate ?? 0
        return childRate > 0 ? childRate.formatAsRate() : "-"
    }

    // MARK: - Other Card Rates (for comparison section)

    private var otherCardRates: [CardRateSummary] {
        let bestName = calculator.bestCard?.name
        return (calculator.bestCards + calculator.nextCards)
            .filter { $0.name != bestName }
            .sorted {
                if $0.effectiveCashBackRate != $1.effectiveCashBackRate {
                    return $0.effectiveCashBackRate > $1.effectiveCashBackRate
                }
                return $0.name < $1.name
            }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Rate Helpers

    private func preferredRateText(for summary: CardRateSummary) -> String {
        showEffectiveRate
            ? summary.effectiveRateDisplayString
            : formatRate(for: summary)
    }

    private func preferredRateMode(for summary: CardRateSummary) -> RatePill.DisplayMode {
        if showEffectiveRate {
            if summary.effectiveCashBackRate == 0 { return .empty }
            return summary.effectiveCashBackRate < 0 ? .effectiveNegative : .effectivePositive
        }
        return summary.rate > 0 ? .points : .empty
    }

    private func formatRate(for summary: CardRateSummary) -> String {
        let r = summary.rate
        if r == floor(r) { return "\(Int(r))x" }
        return String(format: (r * 10).truncatingRemainder(dividingBy: 1) == 0 ? "%.1fx" : "%.2fx", r)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    categoryInfoSection.padding(.top, 8)
                    if showRelatedCategories && !childCategories.isEmpty {
                        relatedCategoriesSection.padding(.top, 16)
                    }
                    recommendationStack.padding(.top, 24)
                    Spacer(minLength: 40)
                }
            }
            .background(Color.churOffWhite)

            SheetDismissButton { dismiss() }
        }
        .sheet(item: $selectedChild) { child in
            CategoryDetailSheetParallax(
                category: child,
                parentCategory: category,
                rate: calculator(for: child).bestCard?.rate ?? 0,
                cards: cards,
                allCategories: allCategories,
                currentRegionCodeOverride: currentRegionCodeOverride
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        PatternHeaderBanner(imageName: "HeaderPattern1") {
            CategoryIconView(category: category, font: .system(size: 40))
        }
    }

    // MARK: - Category Info

    private var categoryInfoSection: some View {
        VStack(spacing: 12) {
            Text(category.displayName)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.churDarkGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    capsuleBubble(
                        text: headerLabel,
                        icon: headerLabel == "SUB-CATEGORY" ? "arrow.turn.down.right" : "folder.fill"
                    )
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
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(Color.churDarkGray)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.churOlive.opacity(0.45))
        .clipShape(Capsule())
    }

    // MARK: - Related Categories

    private var relatedCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RELATED CATEGORIES")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .kerning(1.2)
                .foregroundStyle(Color.churMediumGray)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(childCategories, id: \.id) { child in
                        Button {
                            selectedChild = child
                        } label: {
                            HStack(spacing: 6) {
                                Text(child.emoji)
                                    .font(.churBigTitle4())

                                Text(rateText(for: child))
                                    .font(.churCaption())
                                    .foregroundStyle(Color.churOlive)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.churOlive.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Recommendation Stack

    private var recommendationStack: some View {
        VStack(spacing: 20) {
            if let best = calculator.bestCard {
                tileContainer(title: "BEST CARD TO USE", bannerColor: .churGold) {
                    bestCardContent(for: best)
                }

                if !otherCardRates.isEmpty {
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

    // MARK: - Tile Container

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

    // MARK: - Best Card Content

    private func bestCardContent(for summary: CardRateSummary) -> some View {
        let card = cards.first(where: { $0.name == summary.name })
        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                CardThumbnailView(card: card, width: 90, height: 58)
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

            if showFormula {
                HStack(spacing: 0) {
                    rateColumn(label: "Card Rate", text: formatRate(for: summary), mode: .points)
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

    // MARK: - Comparison Content

    private var comparisonContent: some View {
        Group {
            if isExpanded {
                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        ForEach(otherCardRates.prefix(5), id: \.name) { comparisonRow(for: $0) }
                    }.padding(16)

                    toggleButton(text: "Show Less", icon: "chevron.up", expanded: false)
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
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.churMediumGray)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 20)
                }
            }
        }.transition(.opacity)
    }

    // MARK: - Comparison Row

    private func comparisonRow(for summary: CardRateSummary) -> some View {
        let card = cards.first(where: { $0.name == summary.name })
        return HStack(spacing: 12) {
            CardThumbnailView(card: card, width: 60, height: 38).shadow(color: .black.opacity(0.08), radius: 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.name).font(.churRowText()).foregroundStyle(Color.churDarkGray).lineLimit(1)
                Text(card.map { IssuerDatabase.byName[$0.issuer]?.shortName ?? $0.issuer } ?? "").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.churMediumGray).lineLimit(1)
            }
            Spacer()
            if showFormula {
                HStack(spacing: 6) {
                    RatePill(text: formatRate(for: summary), displayMode: .points, size: .medium)
                    RatePill(text: summary.effectiveRateDisplayString, displayMode: summary.effectiveCashBackRate < 0 ? .effectiveNegative : .effectivePositive, size: .small)
                }
            } else {
                RatePill(text: preferredRateText(for: summary), displayMode: preferredRateMode(for: summary), size: .medium)
            }
        }
        .padding(12).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Small Helpers

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

    private var noCardView: some View {
        Text("No Matching Cards")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.churMediumGray)
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.churTiles))
    }
}
