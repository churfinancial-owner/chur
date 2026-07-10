//
//  ParentCategoryPopup.swift
//  Chur
//
//  Created by Pak Ho on 1/25/26.
//

import SwiftUI
import SwiftData

struct ParentCategoryParallaxSheet: View {
    let category: SpendingCategory
    let rate: Double
    let cards: [CreditCard]
    let allCategories: [SpendingCategory]
    let currentRegionCodeOverride: String?
    var headerLabel: String = "GENERAL CATEGORY"
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
                ).padding(.top, 24)
                if showRelatedCategories && !childCategories.isEmpty {
                    relatedCategoriesSection.padding(.top, 22)
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
        VStack(alignment: .leading, spacing: 0) {
            HeaderCapsuleBubble(
                text: headerLabel,
                icon: headerLabel == "SUB-CATEGORY" ? "arrow.turn.down.right" : "folder.fill"
            )

            Text(category.displayName)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.churDarkGray)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.top, 10)

            HStack(spacing: 6) {
                Text("Here's what earns you the most.")
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
            PopupHeaderWatermark(categoryID: category.id) {
                Text(category.emoji)
                    .font(.system(size: 80))
                    .opacity(1)
            }
        }
        .clipped()
        .background(Color.churOffWhite)
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
