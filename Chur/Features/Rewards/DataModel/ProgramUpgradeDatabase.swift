//
//  ProgramUpgradeDatabase.swift
//  Chur
//
//  Created by Pak Ho on 4/5/26.
//

import Foundation

// MARK: - Program Upgrade Rule

struct ProgramUpgradeRule {
    let id: String
    let sourceProgram: String           // e.g. "Chase Cash Back Rewards"
    let targetProgram: String           // e.g. "Ultimate Rewards"
    let eligibleTemplateIDs: Set<String> // Cards that CAN be upgraded
    let triggerTemplateIDs: Set<String>  // Cards whose presence triggers the upgrade
}

// MARK: - Program Upgrade Proposal

/// A proposed program change for a single card, shown to the user for confirmation.
struct ProgramUpgradeProposal: Identifiable {
    let id: String          // card.id for uniqueness
    let card: CreditCard
    let fromProgram: String // current program on the card
    let toProgram: String   // proposed new program
    let isUpgrade: Bool     // true = upgrade (higher value), false = downgrade
}

// MARK: - Program Upgrade Database

struct ProgramUpgradeDatabase {

    /// All loaded upgrade rules.
    static let all: [ProgramUpgradeRule] = loadRules()

    /// Returns upgrade rules where the given templateID is an eligible card.
    static func rules(forEligibleCard templateID: String) -> [ProgramUpgradeRule] {
        all.filter { $0.eligibleTemplateIDs.contains(templateID) }
    }

    /// Given the user's wallet, returns the resolved (upgraded) program name
    /// for an eligible card, or nil if no upgrade applies.
    static func resolvedProgram(
        forEligibleTemplateID templateID: String,
        walletTemplateIDs: Set<String>
    ) -> String? {
        for rule in rules(forEligibleCard: templateID) {
            if !rule.triggerTemplateIDs.isDisjoint(with: walletTemplateIDs) {
                return rule.targetProgram
            }
        }
        return nil
    }

    /// Returns the source (default/template) program for an eligible card.
    static func sourceProgram(forEligibleTemplateID templateID: String) -> String? {
        rules(forEligibleCard: templateID).first?.sourceProgram
    }

    /// True if `program` is the upgrade target of `sourceProgram` for this card's
    /// template — i.e. the name was set by an auto program upgrade, not drift
    /// from the template. Used by CardSyncService to avoid reverting upgrades.
    static func isUpgradedProgram(_ program: String, sourceProgram: String, templateID: String?) -> Bool {
        guard let templateID else { return false }
        return rules(forEligibleCard: templateID).contains {
            $0.sourceProgram == sourceProgram && $0.targetProgram == program
        }
    }

    /// Finds a user-customized point value for the given program anywhere in the wallet.
    static func customPointValue(for program: String, in cards: [CreditCard]) -> Double? {
        for card in cards {
            for reward in card.rewards where reward.rewardProgramName == program && reward.hasCustomPointValue {
                return reward.pointCashValue
            }
            for plan in card.rewardPlans {
                for reward in plan.rewards where reward.rewardProgramName == program && reward.hasCustomPointValue {
                    return reward.pointCashValue
                }
            }
        }
        return nil
    }

    /// All possible programs this card could be assigned to (source + target).
    /// Returns empty array if the card has no upgrade rules.
    static func availablePrograms(forTemplateID templateID: String) -> [String] {
        var programs: [String] = []
        for rule in rules(forEligibleCard: templateID) {
            if !programs.contains(rule.sourceProgram) {
                programs.append(rule.sourceProgram)
            }
            if !programs.contains(rule.targetProgram) {
                programs.append(rule.targetProgram)
            }
        }
        return programs
    }

    // MARK: - Detection

    /// Detects pending program changes across all wallet cards.
    /// Returns proposals for cards that should upgrade or downgrade but haven't yet.
    /// Skips cards with a manual override (`rewardProgramOverride != nil`).
    static func detectPendingChanges(cards: [CreditCard]) -> [ProgramUpgradeProposal] {
        let walletTemplateIDs = Set(cards.compactMap { $0.templateID })
        var proposals: [ProgramUpgradeProposal] = []

        for card in cards {
            guard let templateID = card.templateID else { continue }
            guard card.rewardProgramOverride == nil else { continue }

            for rule in rules(forEligibleCard: templateID) {
                let hasTrigger = !rule.triggerTemplateIDs.isDisjoint(with: walletTemplateIDs)
                let currentProgram = card.activeRewards.first?.rewardProgramName

                if hasTrigger && currentProgram == rule.sourceProgram {
                    // Can upgrade: source → target
                    proposals.append(ProgramUpgradeProposal(
                        id: card.id,
                        card: card,
                        fromProgram: rule.sourceProgram,
                        toProgram: rule.targetProgram,
                        isUpgrade: true
                    ))
                } else if !hasTrigger && currentProgram == rule.targetProgram {
                    // Should downgrade: target → source
                    proposals.append(ProgramUpgradeProposal(
                        id: card.id,
                        card: card,
                        fromProgram: rule.targetProgram,
                        toProgram: rule.sourceProgram,
                        isUpgrade: false
                    ))
                }
            }
        }

        return proposals
    }

    // MARK: - Apply

    /// Applies a single proposal: rewrites rewardProgramName and pointCashValue
    /// on all rewards of the card. If the wallet already has a user-customized
    /// value for the target program, that value is carried over instead of the default.
    static func applyProposal(_ proposal: ProgramUpgradeProposal, wallet: [CreditCard] = []) {
        let customValue = customPointValue(for: proposal.toProgram, in: wallet)
        let newValue = customValue ?? RewardProgramDefaults.defaultValue(for: proposal.toProgram)?.pointCashValue

        for reward in proposal.card.rewards where reward.rewardProgramName == proposal.fromProgram {
            reward.rewardProgramName = proposal.toProgram
            if let newValue {
                reward.pointCashValue = newValue
                reward.hasCustomPointValue = customValue != nil
            }
        }
        for plan in proposal.card.rewardPlans {
            for reward in plan.rewards where reward.rewardProgramName == proposal.fromProgram {
                reward.rewardProgramName = proposal.toProgram
                if let newValue {
                    reward.pointCashValue = newValue
                    reward.hasCustomPointValue = customValue != nil
                }
            }
        }
    }

    /// Applies all proposals in the array.
    static func applyAll(_ proposals: [ProgramUpgradeProposal], wallet: [CreditCard] = []) {
        for proposal in proposals {
            applyProposal(proposal, wallet: wallet)
        }
    }

    // MARK: - Alert Formatting

    /// Groups proposals by program transition and builds a clear per-group message.
    static func formatAlertMessage(for proposals: [ProgramUpgradeProposal]) -> String {
        // Group by (fromProgram → toProgram)
        var groups: [(from: String, to: String, cards: [String])] = []
        for proposal in proposals {
            if let idx = groups.firstIndex(where: { $0.from == proposal.fromProgram && $0.to == proposal.toProgram }) {
                groups[idx].cards.append(proposal.card.name)
            } else {
                groups.append((from: proposal.fromProgram, to: proposal.toProgram, cards: [proposal.card.name]))
            }
        }

        let isUpgrade = proposals.first?.isUpgrade == true
        return groups.map { group in
            let cardList = group.cards.joined(separator: ", ")
            if isUpgrade {
                return "\(cardList): \(group.from) → \(group.to)"
            } else {
                return "\(cardList): \(group.from) → \(group.to)"
            }
        }.joined(separator: "\n")
    }

    // MARK: - Loading

    private static func loadRules() -> [ProgramUpgradeRule] {
        guard let url = Bundle.main.url(forResource: "SeedDataProgramUpgrades", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let jsonRules = try? JSONDecoder().decode([_UpgradeRuleJSON].self, from: data)
        else { return [] }

        return jsonRules.map { json in
            ProgramUpgradeRule(
                id: json.id,
                sourceProgram: json.sourceProgram,
                targetProgram: json.targetProgram,
                eligibleTemplateIDs: Set(json.eligibleTemplateIDs),
                triggerTemplateIDs: Set(json.triggerTemplateIDs)
            )
        }
    }
}

// MARK: - Private JSON Shape

private struct _UpgradeRuleJSON: Codable {
    let id: String
    let sourceProgram: String
    let targetProgram: String
    let eligibleTemplateIDs: [String]
    let triggerTemplateIDs: [String]
}
