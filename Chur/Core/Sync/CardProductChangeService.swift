//
//  CardProductChangeService.swift
//  Chur
//
//  Card lifecycle transitions: Cancel and Product Change.
//  Both preserve the wallet card's identity (id, dateAdded, approvedDate, note) and
//  usage history — neither ever deletes the CreditCard row.

import Foundation
import SwiftData

struct CardProductChangeService {

    /// Marks a card cancelled. It stops appearing in the wallet and pricing calculations,
    /// but its history (benefits, usage, reward plans) is kept and it can be reactivated.
    static func cancel(card: CreditCard) {
        card.status = "cancelled"
        card.cancelledDate = .current()
    }

    /// Reverses `cancel(card:)`.
    static func reactivate(card: CreditCard) {
        card.status = "active"
        card.cancelledDate = nil
    }

    /// Switches a wallet card from its current template to a new one (e.g. Citi Costco
    /// Visa → Citi Custom Cash), preserving `id`/`dateAdded`/`approvedDate`/`note`/usage
    /// history while archiving the old benefits/reward plans (kept, not deleted) and
    /// building fresh ones from the new template.
    ///
    /// Returns `false` (no changes made) if `toTemplateID` doesn't resolve to a known template.
    @discardableResult
    static func productChange(card: CreditCard, toTemplateID: String, modelContext: ModelContext) -> Bool {
        guard CardDatabase.getCard(id: toTemplateID) != nil else { return false }

        let now = Date.current()
        let fromTemplateID = card.templateID ?? "unknown"

        // Archive (never delete) the old benefits and non-custom reward plans so their
        // usage history / rate history stays queryable, but they stop counting as "current".
        for benefit in card.benefits where benefit.archivedDate == nil {
            benefit.archivedDate = now
        }
        for plan in card.rewardPlans where !plan.isCustomPlan && plan.archivedDate == nil {
            plan.archivedDate = now
            plan.isDefault = false
        }
        card.selectedPlanID = nil

        // New product = new defaults; user customizations belonged to the old product.
        card.hasCustomImage = false
        card.hasCustomAnnualFee = false
        card.hasCustomForeignFee = false
        card.slotSelections = [:]
        card.rewardProgramOverride = nil

        card.templateID = toTemplateID
        CardSyncService.syncCard(card, modelContext: modelContext)

        let event = CardProductChangeEvent(
            cardID: card.id,
            fromTemplateID: fromTemplateID,
            toTemplateID: toTemplateID,
            changeDate: now
        )
        modelContext.insert(event)

        try? modelContext.save()
        return true
    }
}
