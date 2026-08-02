import SwiftUI

struct RewardSetupSection: View {
    let card: CreditCard
    let categories: [SpendingCategory]
    let user: User?
    @Binding var activeSheet: CardInfoContentView.ActiveSheet?

    var rewardPlanDisplay: String {
        card.activePlan?.name ?? (card.rewards.isEmpty ? String(localized: "No plan selected", locale: AppLocale.current) : String(localized: "Current Rewards", locale: AppLocale.current))
    }

    var boostDisplay: String {
        guard let program = card.boostProgram, let tier = user?.boostEnrollments[program.id] else { return String(localized: "Not enrolled", locale: AppLocale.current) }
        let pct = Int((BoostProgramDatabase.multiplier(programID: program.id, tierName: tier) - 1.0) * 100)
        return "\(tier) (+\(pct)%)"
    }

    var uniqueProgramSummary: String {
        let groups = Dictionary(grouping: card.activeRewards, by: { $0.rewardProgramName })
        return groups.compactMap { (name, rewards) -> String? in
            guard let val = rewards.first?.pointCashValue else { return nil }
            let isCustom = !RewardProgramDefaults.isDefault(programName: name, pointCashValue: val)
            let formatted = (val * 100).truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", val * 100)
                : String(format: "%.2f", val * 100)
            return "\(name): \(formatted)¢\(isCustom ? " ✎" : "")"
        }.sorted().joined(separator: "  ·  ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardSectionHeader(title: String(localized: "REWARD SETUP", locale: AppLocale.current))
            VStack(spacing: 0) {
                if card.activeRewards.contains(where: { $0.isUserConfigurable }) {
                    configurableRow
                    CardRowDivider()
                }
                DetailRow(label: String(localized: "Reward Plan", locale: AppLocale.current), value: rewardPlanDisplay, isEditable: card.hasMultiplePlans) {
                    activeSheet = .rewardPlan
                }
                CardRowDivider()
                DetailRow(label: String(localized: "Point Values", locale: AppLocale.current), value: uniqueProgramSummary, isEditable: true) {
                    activeSheet = .pointValues
                }
                if card.boostProgram != nil {
                    CardRowDivider()
                    DetailRow(label: String(localized: "Relationship Boost", locale: AppLocale.current), value: boostDisplay, isEditable: true) {
                        activeSheet = .boost
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var configurableRow: some View {
        let configured = card.activeRewards.filter { reward in
            guard reward.isUserConfigurable,
                  let cats = reward.categories, !cats.isEmpty else { return false }
            return cats.contains { id in categories.contains { $0.id == id } }
        }
        let total = card.activeRewards.filter { $0.isUserConfigurable }.count

        return Group {
            if configured.isEmpty {
                DetailRow(label: String(localized: "Bonus Categories", locale: AppLocale.current), value: "0/\(total) configured", isEditable: true) {
                    activeSheet = .configurableRewards
                }
            } else {
                Button { activeSheet = .configurableRewards } label: {
                    HStack {
                        Text("Bonus Categories")
                            .font(.churRowText())
                            .foregroundStyle(Color.churDarkGray)
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(configured.compactMap { r in categories.first { $0.id == r.categories?.first } }, id: \.id) { cat in
                                CategoryIconView(category: cat, font: .system(size: 16)).frame(width: 24, height: 24)
                            }
                        }
                        Image(systemName: "chevron.right")
                            .font(.churSmallBold())
                            .foregroundStyle(Color.churMediumGray)
                            .padding(.leading, 4)
                    }
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
