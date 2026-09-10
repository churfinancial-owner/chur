import SwiftUI

struct RewardSetupSection: View {
    let card: CreditCard
    let categories: [SpendingCategory]
    let user: User?
    @Binding var activeSheet: CardInfoContentView.ActiveSheet?
    @Binding var boostProgramID: String?

    var rewardPlanDisplay: String {
        card.activePlan?.name ?? (card.rewards.isEmpty ? AppLocale.string("No plan selected") : AppLocale.string("Current Rewards"))
    }

    /// What the user chose for one program, or "Not enrolled".
    func boostDisplay(for program: BoostProgram) -> String {
        guard let selection = user?.boostEnrollments[program.id] else { return AppLocale.string("Not enrolled") }
        switch program.resolvedSelection {
        case .tier:
            guard let name = selection.tier,
                  let tier = program.resolvedTiers.first(where: { $0.name == name }) else { return AppLocale.string("Not enrolled") }
            return "\(name) (\(BoostValueFormat.text(program: program, tier: tier)))"
        case .allocate:
            let parts = (program.allocation?.categories ?? []).compactMap { id -> String? in
                guard let weight = selection.allocation?[id], weight > 0 else { return nil }
                return "\(categoryName(id)) ×\(weight)"
            }
            return parts.isEmpty ? AppLocale.string("Not enrolled") : parts.joined(separator: " · ")
        case .pickOne:
            return selection.pick.map(categoryName) ?? AppLocale.string("Not enrolled")
        case .always:
            return program.name
        }
    }

    private func categoryName(_ id: String) -> String {
        categories.first { $0.id == id }?.displayName ?? id
    }

    /// Enrolled layers that only fire on a transaction the card info screen cannot
    /// see (cross-border, a channel), so the earning-rate rows above do not show them.
    private func scopeNote(for program: BoostProgram) -> String? {
        guard user?.boostEnrollments[program.id] != nil, let scope = program.appliesTo else { return nil }
        var parts: [String] = []
        if scope.crossBorder == true { parts.append(AppLocale.string("foreign spend")) }
        if let channels = scope.channels, !channels.isEmpty {
            parts.append(channels.map { $0 == "in_store" ? AppLocale.string("in store") : $0 }.joined(separator: "/"))
        }
        guard !parts.isEmpty else { return nil }
        return AppLocale.string("Applies on") + " " + parts.joined(separator: ", ")
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
                ForEach(card.enrollableBoostPrograms, id: \.id) { program in
                    CardRowDivider()
                    DetailRow(label: program.name, value: boostDisplay(for: program), isEditable: true) {
                        boostProgramID = program.id
                        activeSheet = .boost
                    }
                    if let note = scopeNote(for: program) {
                        Text(note)
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
