//
//  RewardProgramEditorSheet.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

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

    private var isAutoMode: Bool {
        card.rewardProgramOverride == nil
    }

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
                // Pass the actual card objects instead of just the count
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
                // Append the full card object to the list for this program
                stats[program]?.associatedCards.append(c)
            }
        }
        return stats
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 0) {
                        Text("🪙").font(.churBigTitle2())
                        Text("Set a custom valuation for your points and miles. This override applies to all cards sharing this rewards program.")
                            .font(.churFootnote())
                            .foregroundStyle(Color.churMediumGray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                if upgradeOptions.count > 1 {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Reward Program")
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
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Color.churOlive)
                                    }
                                }
                            }

                            if !isAutoMode {
                                Button {
                                    resetToAutoProgram()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.churSmall())
                                        Text("Reset to auto (\(autoResolvedProgram))")
                                            .font(.churSmall())
                                    }
                                    .foregroundStyle(Color.churWarning)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                ForEach(programRowModels, id: \.programName) { row in
                    ProgramValueRow(
                        programName: row.programName,
                        currentValue: row.currentValue,
                        defaultValue: row.defaultValue,
                        // Update your ProgramValueRow view to accept [CreditCard]
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
                }
            }
            .navigationTitle("Point Values")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.churOlive)
                        .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Program Switching Actions

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

// MARK: - Updated Internal Structures
private struct ProgramValueRowModel {
    let programName: String
    let currentValue: Double
    let defaultValue: Double?
    let associatedCards: [CreditCard] // Now holds the full card objects
    let isDefault: Bool
    
    // Computed property if you still need the count text in the UI
    var cardCount: Int { associatedCards.count }
}

private struct ProgramStats {
    var firstSeenValue: Double
    var associatedCards: [CreditCard] // Changed from cardCount: Int
}
