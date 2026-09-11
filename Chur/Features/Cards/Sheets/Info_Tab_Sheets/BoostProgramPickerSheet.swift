import SwiftUI
import SwiftData

/// Edits the user's selection for one boost program (an earning layer, P1f):
/// a tier, an allocation of weights across categories, or one pick.
struct BoostProgramPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let card: CreditCard
    /// The program to edit. `nil` falls back to the card's first enrollable program,
    /// for any caller that predates a card sitting under several programs.
    var programID: String? = nil

    @Query private var users: [User]
    @Query private var categories: [SpendingCategory]
    private var user: User? { users.first }

    private var program: BoostProgram? {
        if let programID, let found = BoostProgramDatabase.program(id: programID) { return found }
        return card.enrollableBoostPrograms.first
    }

    private var selection: ProgramSelection? {
        guard let id = program?.id else { return nil }
        return user?.boostEnrollments[id]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView

                    if let program {
                        switch program.resolvedSelection {
                        case .tier:     tiersSection(program: program)
                        case .allocate: allocationSection(program: program)
                        case .pickOne:  optionsSection(program: program)
                        case .always:   EmptyView()
                        }
                        noneRow(program: program)
                        if let footnote = program.footnote {
                            footnoteView(text: footnote)
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding()
            }
            .background(Color.churOffWhite)
            .navigationTitle(program?.name ?? AppLocale.string("Relationship Boost"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    ChurDoneButton { dismiss() }
                }
                .churBareToolbarBackground()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 0) {
            Text("🏦")
                .font(.churBigTitle1())

            if let program {
                Text(headerText(for: program))
                    .font(.churCaptionRegular())
                    .foregroundStyle(Color.churMediumGray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    private func headerText(for program: BoostProgram) -> String {
        switch program.resolvedSelection {
        case .tier:
            return "Select your \(card.issuer) \(program.name) tier to apply it to this card's earning rates."
        case .allocate:
            let total = program.allocation?.total ?? 0
            return "Spread \(total) extra \(program.name) weights across the categories, the way you registered them with \(card.issuer)."
        case .pickOne:
            return "Choose the \(program.name) category you registered with \(card.issuer)."
        case .always:
            return program.name
        }
    }

    // MARK: - Tiers

    private func tiersSection(program: BoostProgram) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("YOUR TIER")

            VStack(spacing: 0) {
                ForEach(program.resolvedTiers, id: \.name) { tier in
                    TierRow(
                        tier: tier,
                        program: program,
                        isSelected: selection?.tier == tier.name
                    ) {
                        write(ProgramSelection(tier: tier.name), for: program)
                    }

                    if tier.name != program.resolvedTiers.last?.name {
                        Divider().padding(.horizontal, 16).opacity(0.5)
                    }
                }
            }
            .modifier(CardStack())
        }
    }

    // MARK: - Allocation

    private func allocationSection(program: BoostProgram) -> some View {
        let allocation = program.allocation
        let total = allocation?.total ?? 0
        let assigned = selection?.allocatedTotal ?? 0
        let perUnit = BoostValueFormat.perUnitText(program: program)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("YOUR ALLOCATION")
                Spacer()
                Text("\(assigned) of \(total) assigned")
                    .font(.churSmallBold())
                    .foregroundStyle(assigned == total ? Color.churOlive : Color.churMediumGray)
            }

            VStack(spacing: 0) {
                ForEach(allocation?.categories ?? [], id: \.self) { categoryID in
                    let weight = selection?.allocation?[categoryID] ?? 0
                    AllocationRow(
                        title: categoryName(categoryID),
                        emoji: categories.first { $0.id == categoryID }?.emoji,
                        weight: weight,
                        valueText: weight > 0 ? BoostValueFormat.scaledText(program: program, weight: weight) : perUnit,
                        canIncrement: assigned < total && weight < (allocation?.maxPerCategory ?? total),
                        canDecrement: weight > 0
                    ) { delta in
                        adjust(categoryID, by: delta, in: program)
                    }

                    if categoryID != allocation?.categories.last {
                        Divider().padding(.horizontal, 16).opacity(0.5)
                    }
                }
            }
            .modifier(CardStack())
        }
    }

    // MARK: - Pick one

    private func optionsSection(program: BoostProgram) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("YOUR CATEGORY")

            VStack(spacing: 0) {
                ForEach(program.options ?? [], id: \.self) { option in
                    OptionRow(
                        title: categoryName(option),
                        emoji: categories.first { $0.id == option }?.emoji,
                        valueText: BoostValueFormat.perUnitText(program: program),
                        isSelected: selection?.pick == option
                    ) {
                        write(ProgramSelection(pick: option), for: program)
                    }

                    if option != program.options?.last {
                        Divider().padding(.horizontal, 16).opacity(0.5)
                    }
                }
            }
            .modifier(CardStack())
        }
    }

    // MARK: - Shared rows

    private func noneRow(program: BoostProgram) -> some View {
        Button {
            write(nil, for: program)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Not enrolled")
                        .font(.churRowTextMedium())
                        .foregroundStyle(Color.churDarkGray)
                    Text("Use base earning rates only")
                        .font(.churFootnote())
                        .foregroundStyle(Color.churMediumGray)
                }
                Spacer()
                SelectionMark(isSelected: selection == nil)
            }
            .padding(16)
            .modifier(CardStack())
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.churSmallBold())
            .foregroundStyle(Color.churOlive)
            .tracking(0.5)
    }

    private func footnoteView(text: String) -> some View {
        Text(text)
            .font(.churSmall())
            .foregroundStyle(Color.churMediumGray)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    private func categoryName(_ id: String) -> String {
        categories.first { $0.id == id }?.displayName ?? id
    }

    // MARK: - Logic

    private func write(_ newValue: ProgramSelection?, for program: BoostProgram) {
        guard let user else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let newValue {
                user.boostEnrollments[program.id] = newValue
            } else {
                user.boostEnrollments.removeValue(forKey: program.id)
            }
        }
    }

    private func adjust(_ categoryID: String, by delta: Int, in program: BoostProgram) {
        var weights = selection?.allocation ?? [:]
        let next = max(0, (weights[categoryID] ?? 0) + delta)
        if next == 0 { weights.removeValue(forKey: categoryID) } else { weights[categoryID] = next }
        write(weights.isEmpty ? nil : ProgramSelection(allocation: weights), for: program)
    }
}

// MARK: - Value formatting (shared with Reward Setup)

enum BoostValueFormat {
    /// "+25%", "+4%" or "+2X" for a tier.
    static func text(program: BoostProgram, tier: BoostTier) -> String {
        switch program.resolvedMode {
        case .multiply:
            return "+\(Int(((tier.multiplier ?? 1.0) - 1.0) * 100))%"
        case .add:
            return addText(value: tier.value ?? 0, unit: program.resolvedUnit)
        }
    }

    /// The per-weight or fixed value of an allocate / pick-one program.
    static func perUnitText(program: BoostProgram) -> String {
        scaledText(program: program, weight: 1)
    }

    static func scaledText(program: BoostProgram, weight: Int) -> String {
        let value = (program.value ?? 0) * Double(weight)
        switch program.resolvedMode {
        case .multiply: return "×\(trim(value))"
        case .add:      return addText(value: value, unit: program.resolvedUnit)
        }
    }

    private static func addText(value: Double, unit: LayerUnit) -> String {
        switch unit {
        case .rate: return "+\(trim(value))X"
        case .cash: return "+\(trim(value * 100))%"
        }
    }

    private static func trim(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.2f", value)
    }
}

// MARK: - Rows

private struct CardStack: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

private struct SelectionMark: View {
    let isSelected: Bool
    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isSelected ? Color.churOlive : Color.churLightGray.opacity(0.5))
            .font(.churBigTitle4())
    }
}

private struct ValuePill: View {
    let text: String
    let isSelected: Bool
    var body: some View {
        Text(text)
            .font(.churFootnoteBold())
            .foregroundStyle(isSelected ? .white : Color.churOlive)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.churOlive : Color.churOlive.opacity(0.1))
            .clipShape(Capsule())
    }
}

private struct TierRow: View {
    let tier: BoostTier
    let program: BoostProgram
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tier.name)
                        .font(.churRowText())
                        .foregroundStyle(Color.churDarkGray)
                    Text(tier.description)
                        .font(.churFootnote())
                        .foregroundStyle(Color.churMediumGray)
                    // The tier's own cap, when it has one (P1f part 4).
                    if let capLine = ConditionText.cap(tier.cap ?? program.cap) {
                        Text(capLine)
                            .font(.churMicro())
                            .foregroundStyle(Color.churMediumGray)
                    }
                }

                Spacer()

                ValuePill(text: BoostValueFormat.text(program: program, tier: tier), isSelected: isSelected)
                SelectionMark(isSelected: isSelected)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}

private struct OptionRow: View {
    let title: String
    let emoji: String?
    let valueText: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                if let emoji { Text(emoji).font(.churBigTitle4()) }
                Text(title)
                    .font(.churRowText())
                    .foregroundStyle(Color.churDarkGray)
                Spacer()
                ValuePill(text: valueText, isSelected: isSelected)
                SelectionMark(isSelected: isSelected)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}

private struct AllocationRow: View {
    let title: String
    let emoji: String?
    let weight: Int
    let valueText: String
    let canIncrement: Bool
    let canDecrement: Bool
    let onAdjust: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            if let emoji { Text(emoji).font(.churBigTitle4()) }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.churRowText())
                    .foregroundStyle(Color.churDarkGray)
                Text(valueText)
                    .font(.churFootnote())
                    .foregroundStyle(weight > 0 ? Color.churOlive : Color.churMediumGray)
            }
            Spacer()
            HStack(spacing: 10) {
                stepButton("minus.circle.fill", enabled: canDecrement) { onAdjust(-1) }
                Text("\(weight)")
                    .font(.churRowTextMedium())
                    .foregroundStyle(weight > 0 ? Color.churOlive : Color.churMediumGray)
                    .frame(minWidth: 18)
                stepButton("plus.circle.fill", enabled: canIncrement) { onAdjust(1) }
            }
        }
        .padding(16)
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.churBigTitle4())
                .foregroundStyle(enabled ? Color.churOlive : Color.churLightGray.opacity(0.5))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
