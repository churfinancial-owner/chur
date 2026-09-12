import SwiftUI

struct RewardSetupSection: View {
    let card: CreditCard
    let categories: [SpendingCategory]
    let user: User?
    @Binding var activeSheet: CardInfoContentView.ActiveSheet?

    var rewardPlanDisplay: String {
        card.activePlan?.name ?? (card.rewards.isEmpty ? AppLocale.string("No plan selected") : AppLocale.string("Current Rewards"))
    }

    /// "Transfer Partners" for the usual one-program card; the program's own name
    /// when a card earns into more than one, so the rows stay distinguishable.
    private func transferLabel(for route: CardTransferRoute) -> String {
        card.transferRoutes.count > 1 ? route.program.programName : AppLocale.string("Transfer Partners")
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
            CardSectionHeader(title: AppLocale.string("REWARD SETUP"))
            VStack(spacing: 0) {
                if card.activeRewards.contains(where: { $0.isUserConfigurable }) {
                    configurableRow
                    CardRowDivider()
                }
                DetailRow(label: AppLocale.string("Reward Plan"), value: rewardPlanDisplay, isEditable: card.hasMultiplePlans) {
                    activeSheet = .rewardPlan
                }
                CardRowDivider()
                DetailRow(label: AppLocale.string("Point Values"), value: uniqueProgramSummary, isEditable: true) {
                    activeSheet = .pointValues
                }
                // Where this card's points can go (P1f). Present only when the card's
                // current reward program has partners — a Chase Freedom on Chase Cash
                // Back Rewards has none until a Sapphire upgrades it to Ultimate Rewards.
                ForEach(card.transferRoutes) { route in
                    CardRowDivider()
                    DetailRow(
                        label: transferLabel(for: route),
                        value: "\(route.partnerCount) " + AppLocale.string("partners"),
                        isEditable: true
                    ) {
                        activeSheet = .transferPartners
                    }
                    if let fee = ConditionText.transferFee(route.fee) {
                        Text(fee)
                            .font(.churMicro())
                            .foregroundStyle(Color.churMediumGray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 8)
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
                DetailRow(label: AppLocale.string("Bonus Categories"), value: "0/\(total) configured", isEditable: true) {
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
