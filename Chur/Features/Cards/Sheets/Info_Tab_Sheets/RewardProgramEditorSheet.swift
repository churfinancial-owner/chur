import SwiftUI
import SwiftData

struct RewardProgramEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allCards: [CreditCard]
    @Bindable var card: CreditCard

    // MARK: - Program Switcher

    private var upgradeOptions: [String] {
        guard let templateID = card.templateID else { return [] }
        return ProgramUpgradeDatabase.availablePrograms(forTemplateID: templateID)
    }

    private var currentProgramName: String {
        card.activeRewards.first?.rewardProgramName ?? "Unknown"
    }

    private var isAutoMode: Bool { card.rewardProgramOverride == nil }

    private var autoResolvedProgram: String {
        guard let templateID = card.templateID else { return currentProgramName }
        let walletTemplateIDs = Set(allCards.compactMap { $0.templateID })
        return ProgramUpgradeDatabase.resolvedProgram(
            forEligibleTemplateID: templateID,
            walletTemplateIDs: walletTemplateIDs
        ) ?? card.templateProgramName ?? currentProgramName
    }

    // MARK: - Point Values

    private var programNames: [String] {
        Array(Set(card.activeRewards.map { $0.rewardProgramName })).sorted()
    }

    private var programRowModels: [ProgramValueRowModel] {
        programNames.map { program in
            let stats = programStatsByName[program]
            let value = stats?.firstSeenValue ?? 0.01
            let def = RewardProgramDefaults.defaultValue(for: program)
            return ProgramValueRowModel(
                programName: program,
                currentValue: value,
                defaultValue: def?.pointCashValue,
                associatedCards: stats?.associatedCards ?? [],
                isDefault: RewardProgramDefaults.isDefault(programName: program, pointCashValue: value)
            )
        }
    }

    private var programStatsByName: [String: ProgramStats] {
        var stats: [String: ProgramStats] = [:]
        for c in allCards {
            var programsSeenOnCard = Set<String>()
            for reward in c.activeRewards {
                let program = reward.rewardProgramName
                if stats[program] == nil {
                    stats[program] = ProgramStats(firstSeenValue: reward.pointCashValue, associatedCards: [])
                }
                programsSeenOnCard.insert(program)
            }
            for program in programsSeenOnCard {
                stats[program]?.associatedCards.append(c)
            }
        }
        return stats
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    if upgradeOptions.count > 1 {
                        programSwitcherSection
                    }
                    if !programRowModels.isEmpty {
                        pointValuesSection
                    }
                    Spacer(minLength: 32)
                }
                .padding()
            }
            .background(Color.churOffWhite)
            .navigationTitle("Point Values")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.churRowText())
                        .fontWeight(.bold)
                        .foregroundStyle(Color.churOlive)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("🪙").font(.churBigTitle1())
            Text("Set a custom valuation for your points and miles. This override applies to all cards sharing this rewards program.")
                .font(.churCaptionRegular())
                .foregroundStyle(Color.churMediumGray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Program Switcher Section

    private var programSwitcherSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REWARD PROGRAM")
                .font(.churSmallBold())
                .foregroundStyle(Color.churOlive)
                .tracking(0.5)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Program")
                            .font(.churRowText())
                            .foregroundStyle(Color.churDarkGray)
                        if !isAutoMode {
                            Text("Manual override")
                                .font(.churSmallBold())
                                .foregroundStyle(Color.churWarning)
                        } else {
                            Text("Auto-detected")
                                .font(.churSmall())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Menu {
                        ForEach(upgradeOptions, id: \.self) { program in
                            Button {
                                switchProgram(to: program)
                            } label: {
                                if program == currentProgramName {
                                    Label(program, systemImage: "checkmark")
                                } else {
                                    Text(program)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentProgramName)
                                .font(.churRowText())
                                .foregroundStyle(Color.churOlive)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.churBadgeBold())
                                .foregroundStyle(Color.churOlive)
                        }
                    }
                }
                .padding(16)

                if !isAutoMode {
                    Divider().padding(.horizontal, 16).opacity(0.5)

                    Button { resetToAutoProgram() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise").font(.churSmall())
                            Text("Reset to auto (\(autoResolvedProgram))").font(.churSmall())
                        }
                        .foregroundStyle(Color.churWarning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Point Values Section

    private var pointValuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("POINT VALUES")
                .font(.churSmallBold())
                .foregroundStyle(Color.churOlive)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(programRowModels, id: \.programName) { row in
                    ProgramValueRow(
                        programName: row.programName,
                        currentValue: row.currentValue,
                        defaultValue: row.defaultValue,
                        associatedCards: row.associatedCards,
                        isDefault: row.isDefault,
                        onSave: { newValue in
                            for c in allCards {
                                for reward in c.rewards where reward.rewardProgramName == row.programName {
                                    reward.pointCashValue = newValue
                                    reward.hasCustomPointValue = true
                                }
                                for plan in c.rewardPlans {
                                    for reward in plan.rewards where reward.rewardProgramName == row.programName {
                                        reward.pointCashValue = newValue
                                        reward.hasCustomPointValue = true
                                    }
                                }
                            }
                            try? modelContext.save()
                        },
                        onReset: {
                            if let def = RewardProgramDefaults.defaultValue(for: row.programName) {
                                for c in allCards {
                                    for reward in c.rewards where reward.rewardProgramName == row.programName {
                                        reward.pointCashValue = def.pointCashValue
                                        reward.hasCustomPointValue = false
                                    }
                                    for plan in c.rewardPlans {
                                        for reward in plan.rewards where reward.rewardProgramName == row.programName {
                                            reward.pointCashValue = def.pointCashValue
                                            reward.hasCustomPointValue = false
                                        }
                                    }
                                }
                                try? modelContext.save()
                            }
                        }
                    )

                    if row.programName != programRowModels.last?.programName {
                        Divider().padding(.horizontal, 16).opacity(0.5)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Actions

    private func switchProgram(to newProgram: String) {
        let oldProgram = currentProgramName
        guard newProgram != oldProgram else { return }
        card.rewardProgramOverride = newProgram
        let newDefault = RewardProgramDefaults.defaultValue(for: newProgram)
        for reward in card.rewards where reward.rewardProgramName == oldProgram {
            reward.rewardProgramName = newProgram
            if let def = newDefault { reward.pointCashValue = def.pointCashValue }
        }
        for plan in card.rewardPlans {
            for reward in plan.rewards where reward.rewardProgramName == oldProgram {
                reward.rewardProgramName = newProgram
                if let def = newDefault { reward.pointCashValue = def.pointCashValue }
            }
        }
        try? modelContext.save()
    }

    private func resetToAutoProgram() {
        card.rewardProgramOverride = nil
        let resolved = autoResolvedProgram
        let oldProgram = currentProgramName
        if resolved != oldProgram {
            let newDefault = RewardProgramDefaults.defaultValue(for: resolved)
            for reward in card.rewards where reward.rewardProgramName == oldProgram {
                reward.rewardProgramName = resolved
                if let def = newDefault { reward.pointCashValue = def.pointCashValue }
            }
            for plan in card.rewardPlans {
                for reward in plan.rewards where reward.rewardProgramName == oldProgram {
                    reward.rewardProgramName = resolved
                    if let def = newDefault { reward.pointCashValue = def.pointCashValue }
                }
            }
        }
        try? modelContext.save()
    }
}

// MARK: - Internal Structures

private struct ProgramValueRowModel {
    let programName: String
    let currentValue: Double
    let defaultValue: Double?
    let associatedCards: [CreditCard]
    let isDefault: Bool
    var cardCount: Int { associatedCards.count }
}

private struct ProgramStats {
    var firstSeenValue: Double
    var associatedCards: [CreditCard]
}
