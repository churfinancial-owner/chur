import SwiftUI

/// The issuer programs this card sits under (earning layers, P1f): relationship
/// tiers, HSBC Travel Guru, Red Hot Rewards. One row per program with the user's
/// selection, plus a scope note for layers the earning-rate rows above cannot
/// show because they only fire on a transaction (foreign spend, a channel).
///
/// Its own section rather than rows in Reward Setup: enrolments are per user and
/// span cards, where Reward Setup is this card's own configuration.
struct BoostProgramsSection: View {
    let card: CreditCard
    let categories: [SpendingCategory]
    let user: User?
    @Binding var activeSheet: CardInfoContentView.ActiveSheet?
    @Binding var boostProgramID: String?

    private var programs: [BoostProgram] { card.enrollableBoostPrograms }

    var body: some View {
        if !programs.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                CardSectionHeader(title: AppLocale.string("BONUS PROGRAMS"))
                VStack(spacing: 0) {
                    ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
                        if index > 0 { CardRowDivider() }
                        DetailRow(label: program.name, value: display(for: program), isEditable: true) {
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
    }

    /// What the user chose for one program, or "Not enrolled".
    private func display(for program: BoostProgram) -> String {
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
}
