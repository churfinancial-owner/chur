//
//  ExpiringBenefits.swift
//  Chur
//
//  Single source of truth for "what is expiring soon": every benefit on an
//  active card that is inside its warning window with balance remaining.
//  Used by both ExpiringBenefitsView (live, at open time) and the digest
//  notification body (at its fire date), so their numbers always agree.
//

import Foundation

struct ExpiringBenefitEntry: Identifiable {
    let card: CreditCard
    let benefit: Benefit
    /// Remaining balance for value-based benefits; nil for count-based.
    let remainingBalance: Int?
    let expiryDate: Date
    var id: String { "\(card.id).\(benefit.id)" }
}

enum ExpiringBenefits {

    /// Mirrors BenefitRowViewModel.shouldShowExpiryWarning so results match
    /// the ⏰ badges and the notification schedule.
    static func entries(cards: [CreditCard], on date: Date = Date.current()) -> [ExpiringBenefitEntry] {
        var entries: [ExpiringBenefitEntry] = []

        for card in cards where card.status == "active" {
            let anniversary = Calendar.current.date(from: DateComponents(
                year: card.approvedYear, month: max(1, min(12, card.approvedMonth)), day: 1
            ))

            for benefit in card.benefits {
                guard benefit.isCurrentlyActive, !benefit.isMuted,
                      !benefit.isLocked(approvedMonth: card.approvedMonth, approvedYear: card.approvedYear),
                      let expiry = benefit.effectiveExpiryDate(cardAnniversaryDate: anniversary, on: date)
                else { continue }

                let analyzer = BenefitUsageAnalyzer(benefit: benefit, approvedMonth: card.approvedMonth)
                let remaining = analyzer.remainingBalance(on: date)
                guard (remaining ?? 0) > 0,
                      ReminderTiming.isInWarningWindow(expiry: expiry, now: date)
                else { continue }

                entries.append(ExpiringBenefitEntry(
                    card: card,
                    benefit: benefit,
                    remainingBalance: analyzer.isValueBased ? remaining : nil,
                    expiryDate: expiry
                ))
            }
        }
        return entries
    }

    /// Summary numbers for the digest body. The unused total is only quoted
    /// when every value shares one currency.
    static func summary(cards: [CreditCard], on date: Date) -> (benefits: Int, cards: Int, totalText: String) {
        let entries = entries(cards: cards, on: date)
        let cardCount = Set(entries.map(\.card.id)).count

        let currencies = Set(entries.compactMap { $0.remainingBalance != nil ? $0.benefit.valueCurrency : nil })
        var totalText = ""
        if currencies.count == 1, let currency = currencies.first {
            let total = entries.compactMap(\.remainingBalance).reduce(0, +)
            if total > 0 { totalText = " — \(currency.currencySymbol)\(total) unused" }
        }
        return (entries.count, cardCount, totalText)
    }
}
