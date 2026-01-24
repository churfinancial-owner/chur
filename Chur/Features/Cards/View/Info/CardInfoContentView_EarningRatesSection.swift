//
//  CardInfoContentView_EarningRatesSection.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import SwiftUI

struct EarningRatesSection: View {
    let card: CreditCard
    let categories: [SpendingCategory]
    let boostMultiplier: Double
    let showEffectiveRate: Bool
    let dateRefreshTick: Int
    let onConfigureTap: () -> Void

    // Logic moved from your original file
    private var mainAndSubRates: [(category: SpendingCategory, reward: RewardRate)] {
        let _ = dateRefreshTick
        let now = Date.current()
        return card.activeRewards.flatMap { reward -> [(category: SpendingCategory, reward: RewardRate)] in
            if reward.isUserConfigurable && (reward.categories?.isEmpty ?? true) { return [] }
            if let end = reward.rewardEndDate, end < now { return [] }

            let categoryIDs = reward.categories ?? ["everything"]
            return categoryIDs.compactMap { id -> (SpendingCategory, RewardRate)? in
                guard let found = categories.first(where: { $0.id == id }),
                      (found.level == .parent || found.level == .child) else { return nil }
                guard reward.rate > 1.0 || id == "everything" else { return nil }
                return (found, reward)
            }
        }.sorted {
            if $0.reward.rate != $1.reward.rate { return $0.reward.rate > $1.reward.rate }
            return $0.category.displayName.localizedStandardCompare($1.category.displayName) == .orderedAscending
        }
    }

    private var targetRates: [(category: SpendingCategory, reward: RewardRate)] {
        let _ = dateRefreshTick
        let now = Date.current()
        return card.activeRewards.flatMap { reward -> [(category: SpendingCategory, reward: RewardRate)] in
            if reward.isUserConfigurable && (reward.categories?.isEmpty ?? true) { return [] }
            if let end = reward.rewardEndDate, end < now { return [] }

            let categoryIDs = reward.categories ?? ["everything"]
            return categoryIDs.compactMap { id -> (SpendingCategory, RewardRate)? in
                guard let found = categories.first(where: { $0.id == id }),
                      found.level == .target || found.level == .groupTarget else { return nil }
                guard reward.rate > 1.0 || id == "everything" else { return nil }
                return (found, reward)
            }
        }.sorted {
            if $0.reward.rate != $1.reward.rate { return $0.reward.rate > $1.reward.rate }
            return $0.category.displayName.localizedStandardCompare($1.category.displayName) == .orderedAscending
        }
    }

    private var unconfiguredRewards: [RewardRate] {
        card.activeRewards.filter { $0.isUserConfigurable && ($0.categories?.isEmpty ?? true) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("EARNING RATES")
            
            VStack(alignment: .leading, spacing: 0) {
                if mainAndSubRates.isEmpty && targetRates.isEmpty && unconfiguredRewards.isEmpty {
                    emptyView
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        if !unconfiguredRewards.isEmpty {
                            unconfiguredBanner
                        }
                        
                        if !mainAndSubRates.isEmpty {
                            rateList(items: mainAndSubRates)
                        }
                        
                        if !targetRates.isEmpty {
                            rateSubSection(title: "MERCHANTS", items: targetRates)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // Helper View Builders (Keeping your styling exact)
    private func header(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.churSmallBold())
                .foregroundStyle(Color.churOlive)
                .tracking(1.0)
                .padding([.horizontal, .top], 20)
                .padding(.bottom, 12)
            Divider().padding(.horizontal, 20)
        }
    }

    private func rateList(items: [(category: SpendingCategory, reward: RewardRate)]) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let isUpcoming = item.reward.rewardStartDate.map { $0 > Date.current() } ?? false
                VStack(alignment: .leading, spacing: 4) {
                    ChildCategoryRateRow(
                        category: item.category,
                        rate: item.reward.rate * boostMultiplier,
                        cardName: nil,
                        effectiveRate: item.reward.effectiveCashBackRate * boostMultiplier,
                        showEffectiveRate: showEffectiveRate
                    )
                    .opacity(isUpcoming ? 0.5 : 1.0)

                    if let notes = item.reward.rewardNotes, !notes.isEmpty {
                        Text(notes)
                            .font(.churMicro())
                            .foregroundStyle(Color.churMediumGray)
                            .padding(.leading, 4)
                    }
                    
                    // Badges logic (Rotating/Regular)
                    badgeView(for: item, in: items, isUpcoming: isUpcoming)
                }
            }
        }
    }

    @ViewBuilder
    private func badgeView(for item: (category: SpendingCategory, reward: RewardRate), in items: [(category: SpendingCategory, reward: RewardRate)], isUpcoming: Bool) -> some View {
        if isUpcoming, let start = item.reward.rewardStartDate {
            dateBadge(label: "Rotating · Starts \(start.formatted(.dateTime.month(.abbreviated).day()))", color: .orange)
        } else if item.reward.isRotating, let end = item.reward.rewardEndDate {
            dateBadge(label: "Rotating · Ends \(end.formatted(.dateTime.month(.abbreviated).day()))", color: .green)
        } else if items.contains(where: { $0.category.id == item.category.id && $0.reward.isRotating && !item.reward.isRotating }) {
            dateBadge(label: "Regular", color: .blue)
        }
    }

    private func dateBadge(label: String, color: Color) -> some View {
        Text(label)
            .font(.churBadgeBold())
            .foregroundStyle(color).padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.1)).clipShape(Capsule()).padding(.leading, 4)
    }

    private func rateSubSection(title: String, items: [(category: SpendingCategory, reward: RewardRate)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.bottom, 16)
            Text(title).font(.churSmallBold())
                .foregroundStyle(Color.churOlive).tracking(1.0).padding(.bottom, 8)
            rateList(items: items)
        }
    }

    private var unconfiguredBanner: some View {
        Button(action: onConfigureTap) {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3").foregroundStyle(Color.churOlive)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bonus categories not set up").font(.churCaption()).foregroundStyle(Color.churDarkGray)
                    Text("\(unconfiguredRewards.count) slots need a category").font(.churSmall()).foregroundStyle(Color.churMediumGray)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.churMediumGray)
            }
            .padding(14).background(Color.churOlive.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(ScaleButtonStyle())
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "creditcard.and.123").font(.churTitle2()).foregroundStyle(Color.churLightGray)
            Text("No earning rates defined").font(.churCaptionMedium()).foregroundStyle(Color.churMediumGray)
        }.padding(.vertical, 30).frame(maxWidth: .infinity)
    }
}
