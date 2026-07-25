//
//  CardProductChangeService.swift
//  Chur
//
//  Card lifecycle transitions: Cancel and Product Change.

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

    /// Switches a wallet card to a different product (e.g. Citi Costco Visa → Citi Custom
    /// Cash). This is modeled as **cancelling the old card and adding a new one**, not an
    /// in-place mutation: `fromCard` is cancelled (kept, with its real benefits/reward
    /// plans/usage history intact, exactly like a manual cancel), and a brand-new
    /// `CreditCard` is built from `toTemplateID` the same way the normal "Add Card" flow
    /// does. Only the approved date carries over, so the new card's real-world account age
    /// is preserved; `dateAdded`/`note` start fresh. A `CardProductChangeEvent` links the
    /// two cards for the Card History timeline and the new card's "previously X" note.
    ///
    /// Same-day correction: if `fromCard` was itself created by a product change earlier
    /// *today*, this is treated as fixing that mistake rather than a new hop — the
    /// intermediate card and its event are deleted outright, and the new event links back
    /// to the original card, so the lineage reads as a single direct change.
    ///
    /// Returns the new card, or `nil` if `toTemplateID` doesn't resolve to a known template
    /// (no changes are made in that case).
    @discardableResult
    static func productChange(fromCard: CreditCard, toTemplateID: String, modelContext: ModelContext) -> CreditCard? {
        guard let newTemplate = CardDatabase.getCard(id: toTemplateID) else { return nil }

        let now = Date.current()
        let approvedMonth = fromCard.approvedMonth
        let approvedDay = fromCard.approvedDay
        let approvedYear = fromCard.approvedYear
        var effectiveFromCardID = fromCard.id
        var effectiveFromTemplateID = fromCard.templateID ?? "unknown"

        let fromCardID = fromCard.id
        let incomingEvent = try? modelContext.fetch(
            FetchDescriptor<CardProductChangeEvent>(predicate: #Predicate { $0.toCardID == fromCardID })
        ).first

        if let incomingEvent, Calendar.current.isDate(incomingEvent.changeDate, inSameDayAs: now) {
            // `fromCard` was itself a same-day product change — collapse it away instead
            // of keeping it as a real lineage step.
            effectiveFromCardID = incomingEvent.fromCardID
            effectiveFromTemplateID = incomingEvent.fromTemplateID
            modelContext.delete(incomingEvent)
            modelContext.delete(fromCard)
        } else {
            cancel(card: fromCard)
        }

        let newCard = newTemplate.toCreditCard(modelContext: modelContext)
        newCard.approvedMonth = approvedMonth
        newCard.approvedDay = approvedDay
        newCard.approvedYear = approvedYear

        let event = CardProductChangeEvent(
            fromCardID: effectiveFromCardID,
            toCardID: newCard.id,
            fromTemplateID: effectiveFromTemplateID,
            toTemplateID: toTemplateID,
            changeDate: now
        )
        modelContext.insert(event)

        try? modelContext.save()
        return newCard
    }
}
