import SwiftUI
import SwiftData

// MARK: - Card-specific view helpers for news detail posts where isCardPost == true

extension NewsDetailView {

    func cardHeroSection(card: (cardId: String, template: CardTemplate)?) -> some View {
        ZStack {
            LinearGradient(colors: [brandAccent.opacity(0.5), brandAccent.opacity(0.15), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let card {
                Image(card.template.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
                    .padding(.top, 48)
                    .padding(.bottom, 24)
            }
        }
    }

    var cardChipsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(linkedCardsList, id: \.cardId) { item in
                    let target = allPosts.first(where: { $0.slug?.current == item.cardId })
                    Button { if let target = target { linkedNewsPost = target } } label: {
                        VStack(spacing: 6) {
                            Image(item.template.imageName)
                                .resizable().scaledToFit()
                                .frame(height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)

                            if target != nil {
                                Image(systemName: "arrow.up.right.circle.fill")
                                    .font(.churCaptionRegular()).foregroundStyle(brandAccent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }.padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    var cardRewardRatesSection: some View {
        if let cardItem = linkedCardsList.first,
           let plan = cardItem.template.rewardPlans.first(where: { $0.isDefault })
                   ?? cardItem.template.rewardPlans.first {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showRewards.toggle() }
                } label: {
                    HStack {
                        Text("Rewards")
                            .font(.churHeadline())
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.churCaption())
                            .rotationEffect(.degrees(showRewards ? 90 : 0))
                            .foregroundStyle(Color.churMediumGray)
                    }
                    .padding(.vertical, 16).padding(.horizontal, 20)
                    .background(surfaceColor).clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                if showRewards {
                    cardEarningRatesCard(plan: plan).transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    func cardEarningRatesCard(plan: PlanTemplate) -> some View {
        let allRates = templateRateItems(plan: plan)
        let mainRates = allRates.filter { $0.level == .parent || $0.level == .child }
        let targetRates = allRates.filter { $0.level == .target || $0.level == .groupTarget }
        let programName = plan.rewards.first?.rewardProgramName ?? ""

        if !mainRates.isEmpty || !targetRates.isEmpty {
            VStack(spacing: 0) {
                HStack {
                    Text("EARNING RATES")
                        .font(.churSmallBold())
                        .foregroundStyle(Color.churOlive)
                        .tracking(1.0)
                    Spacer()
                    if !programName.isEmpty {
                        Text(programName)
                            .font(.churMicroBold())
                            .foregroundStyle(Color.churMediumGray)
                            .lineLimit(1)
                    }
                }
                .padding([.horizontal, .top], 20)
                .padding(.bottom, 12)

                Divider().padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 16) {
                    if !mainRates.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(Array(mainRates.enumerated()), id: \.offset) { _, item in
                                ChildCategoryRateRow(
                                    category: item.category,
                                    rate: item.rate,
                                    cardName: nil,
                                    effectiveRate: item.effectiveRate
                                )
                            }
                        }
                    }

                    if !targetRates.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Divider().padding(.bottom, 16)
                            Text("MERCHANTS")
                                .font(.churSmallBold())
                                .foregroundStyle(Color.churOlive)
                                .tracking(1.0)
                                .padding(.bottom, 8)
                            VStack(spacing: 8) {
                                ForEach(Array(targetRates.enumerated()), id: \.offset) { _, item in
                                    ChildCategoryRateRow(
                                        category: item.category,
                                        rate: item.rate,
                                        cardName: nil,
                                        effectiveRate: item.effectiveRate
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .background(surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.04), radius: 20, x: 0, y: 10)
        }
    }

    private func templateRateItems(plan: PlanTemplate) -> [(category: SpendingCategory, rate: Double, effectiveRate: Double, level: CategoryLevel)] {
        var seen = Set<String>()
        return plan.rewards
            .filter { reward in
                guard !reward.isRotating else { return false }
                guard !(reward.isUserConfigurable && (reward.categories?.isEmpty ?? true)) else { return false }
                return reward.rewardEndDate.map { $0 >= Date.current() } ?? true
            }
            .flatMap { reward -> [(SpendingCategory, Double, Double, CategoryLevel)] in
                let catIDs = (reward.categories?.isEmpty ?? true) ? ["everything"] : (reward.categories ?? [])
                return catIDs.compactMap { id in
                    guard let cat = categories.first(where: { $0.id == id }),
                          let level = cat.level,
                          reward.rate > 1.0 || id == "everything"
                    else { return nil }
                    return (cat, reward.rate, reward.rate * reward.pointCashValue, level)
                }
            }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 > b.1 }
                return a.0.displayName.localizedStandardCompare(b.0.displayName) == .orderedAscending
            }
            .filter { seen.insert($0.0.id).inserted }
            .map { ($0.0, $0.1, $0.2, $0.3) }
    }
}
