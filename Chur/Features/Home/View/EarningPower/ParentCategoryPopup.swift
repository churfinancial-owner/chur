//
//  ParentCategoryPopup.swift
//  Chur
//
//  Created by Pak Ho on 1/25/26.
//

import SwiftUI
import SwiftData

/// The two header states this sheet can render. Kept as an identifier-based enum
/// rather than the raw display string, so business logic (icon selection) never
/// has to compare against a localized value — see `CategoryHeaderKind.icon` and
/// `.displayLabel` for the two things that used to be derived from the string.
enum CategoryHeaderKind {
    case general
    case subCategory

    var displayLabel: String {
        switch self {
        case .general: return AppLocale.string("GENERAL CATEGORY")
        case .subCategory: return AppLocale.string("SUB-CATEGORY")
        }
    }

    var icon: String {
        switch self {
        case .general: return "folder.fill"
        case .subCategory: return "arrow.turn.down.right"
        }
    }
}

struct ParentCategoryParallaxSheet: View {
    let category: SpendingCategory
    let rate: Double
    let cards: [CreditCard]
    let allCategories: [SpendingCategory]
    let currentRegionCodeOverride: String?
    var headerKind: CategoryHeaderKind = .general
    var showRelatedCategories: Bool = true

    @Query private var users: [User]
    @State private var showFormula = false
    @State private var selectedChild: SpendingCategory? = nil

    private var boostEnrollments: [String: String] { users.first?.boostEnrollments ?? [:] }
    private var earningPowerTravelModeEnabled: Bool { users.first?.earningPowerTravelModeEnabled ?? false }
    private var isAwayFromHomeRegion: Bool {
        guard let home = RegionDatabase.normalizeRegionCode(users.first?.country),
              let current = RegionDatabase.normalizeRegionCode(currentRegionCodeOverride ?? Locale.current.region?.identifier) else {
            return false
        }
        return home != current
    }
    private var effectiveTravelModeEnabled: Bool { earningPowerTravelModeEnabled && isAwayFromHomeRegion }

    private var effectiveRegion: String? {
        effectiveTravelModeEnabled
            ? RegionDatabase.normalizeRegionCode(currentRegionCodeOverride ?? Locale.current.region?.identifier)
            : RegionDatabase.normalizeRegionCode(users.first?.country)
    }

    // MARK: - Card Rate Calculator

    private var calculator: CardRateCalculator {
        CardRateCalculator(
            cards: cards,
            category: category,
            rate: rate,
            allCategories: allCategories,
            boostEnrollments: boostEnrollments,
            region: effectiveRegion,
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
            region: effectiveRegion,
            channel: nil,
            allowPaymentMethodFallback: false,
            forceCrossBorder: effectiveTravelModeEnabled
        )
    }

    private func rateText(for child: SpendingCategory) -> String {
        let childRate = calculator(for: child).bestCard?.rate ?? 0
        return childRate > 0 ? childRate.formatAsRate() : "-"
    }

    // MARK: - Other Card Rates

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

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                RecommendationStackView(
                    bestCardSummary: calculator.bestCard,
                    otherCardRates: otherCardRates,
                    cards: cards,
                    showFormula: showFormula
                )
                .popupHeroOverlap()
                if showRelatedCategories && !childCategories.isEmpty {
                    relatedCategoriesSection.padding(.top, PopupCardMetrics.stackSpacing)
                }
                Spacer(minLength: 40)
            }
        }
        .background(Color.churOffWhite)
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
        PopupHeroHeader {
            VStack(alignment: .leading, spacing: 0) {
                HeaderCapsuleBubble(
                    text: headerKind.displayLabel,
                    icon: headerKind.icon
                )
                .popupHeroInset()

                Text(category.displayName)
                    .popupHeroTitle()
                    .popupHeroInset()
                    .padding(.top, 10)

                HStack(spacing: 6) {
                    Text("Here's what earns you the most.")
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
            }
        } avatar: {
            // The category's own icon when it has one, its emoji otherwise —
            // sized to the 55pt logo frame, since a Text does not inherit the
            // frame an image gets from .scaledToFit().
            MerchantIconView(iconName: category.iconName,
                             category: category,
                             emojiFont: .system(size: 39))
        }
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
                            HStack(spacing: 7) {
                                Text(child.emoji)
                                    .font(.system(size: 16))
                                Text(child.displayName)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.churDarkGray)
                                Text(rateText(for: child))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
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

}
