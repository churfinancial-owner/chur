//
//  CreditCard_Transfers.swift
//  Chur
//
//  P1f part 5. Whether a card's points move to an airline, and what a mile costs.
//
//  Transferability is not a field. It follows from the reward program the card is
//  currently on: a Freedom sits on Chase Cash Back Rewards, which has no partners,
//  and `ProgramUpgradeDatabase` moves it to Ultimate Rewards once a Sapphire joins
//  the wallet. So there is nothing to keep in sync — ask the program.
//

import Foundation

/// One of a card's reward programs that can move points to a partner.
struct CardTransferRoute: Identifiable {
    let program: TransferProgram
    let pointCashValue: Double
    /// The cheapest mile on this program, and who offers it.
    let best: (partner: TransferPartner, costPerMile: Double)?

    var id: String { program.programName }
    var partnerCount: Int { program.partners.count }

    /// The currency the cost is quoted in, from the card's own reward rows.
    let currency: String

    /// What this card pays to move points out: its own override when the card
    /// has one (a Prestige with the fee waived), otherwise the program's.
    let fee: TransferFee?
}

extension CreditCard {
    /// This card's own transfer-fee override, from its template. nil means the
    /// reward program's fee applies unchanged.
    var transferFeeOverride: TransferFee? {
        guard let templateID else { return nil }
        return CardDatabase.getCard(id: templateID)?.transferFee
    }

    /// The distinct reward programs this card's active rows earn into.
    var rewardProgramNames: [String] {
        var seen = Set<String>()
        return activeRewards.compactMap { reward in
            seen.insert(reward.rewardProgramName).inserted ? reward.rewardProgramName : nil
        }
    }

    /// The card's programs that have transfer partners, with the cheapest mile on each.
    /// Empty means this card earns cash, or points that stay put.
    var transferRoutes: [CardTransferRoute] {
        rewardProgramNames.compactMap { name in
            guard let program = TransferPartnerDatabase.program(named: name) else { return nil }
            let reward = activeRewards.first { $0.rewardProgramName == name }
            let value = reward?.pointCashValue ?? RewardProgramDefaults.defaultValue(for: name)?.pointCashValue ?? 0.01
            return CardTransferRoute(
                program: program,
                pointCashValue: value,
                best: program.bestRoute(pointCashValue: value),
                currency: reward?.pointCashValueCurrency ?? RewardProgramDefaults.defaultValue(for: name)?.currency ?? "USD",
                fee: transferFeeOverride ?? program.fee
            )
        }
    }

    /// Whether any of this card's points reach an airline or hotel today.
    var earnsTransferablePoints: Bool { !transferRoutes.isEmpty }

    /// The programs this card *could* reach by adding a trigger card to the wallet
    /// (Freedom plus Sapphire). Empty when the card has no upgrade rule, or is
    /// already on the upgraded program.
    var potentialTransferProgramNames: [String] {
        guard let templateID else { return [] }
        let current = Set(rewardProgramNames)
        return ProgramUpgradeDatabase.availablePrograms(forTemplateID: templateID)
            .filter { !current.contains($0) && TransferPartnerDatabase.program(named: $0) != nil }
    }
}
