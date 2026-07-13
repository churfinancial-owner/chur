//
//  ReminderScheduler_AnnualFee.swift
//  Chur
//
//  Annual fee reminder planner. The fee date is the card's anniversary
//  (approvedMonth/approvedDay each year). One notice per year, lead time
//  user-configurable (ReminderTiming.annualFeeLeadDays, default 0 = the
//  day the fee posts). Cards with a $0 fee never remind — downgrading a
//  card to no-fee (via the custom fee field) silences it naturally.
//
//  Fee reminders are always delivered individually — they are rare and
//  high-stakes, so the digest never absorbs them.
//

import Foundation

extension ReminderScheduler {

    func annualFeeReminders(for cards: [CreditCard]) -> [PlannedReminder] {
        let now = Date.current()
        let calendar = Calendar.current
        var planned: [PlannedReminder] = []

        for card in cards where card.status == "active" && card.annualFee > 0 {
            let components = DateComponents(
                month: max(1, min(12, card.approvedMonth)),
                day: max(1, min(31, card.approvedDay))
            )
            guard let feeDate = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)
            else { continue }

            let feeYear = calendar.component(.year, from: feeDate)
            let symbol = card.currency.currencySymbol
            let dateText = feeDate.formatted(.dateTime.month(.abbreviated).day())

            let lead = ReminderTiming.annualFeeLeadDays
            guard let fireDate = Self.fireDate(daysBefore: lead, deadline: feeDate, now: now) else { continue }
            let when = Self.relativeWhenText(from: fireDate, to: feeDate)

            planned.append(PlannedReminder(
                identifier: "\(Self.identifierPrefix)fee.\(card.id).\(feeYear).\(lead)d",
                kind: .annualFee,
                fireDate: fireDate,
                title: card.name,
                subtitle: "Annual fee",
                body: when == "today"
                    ? "\(symbol)\(card.annualFee) annual fee posts today. Time to review keep, downgrade, or cancel."
                    : "\(symbol)\(card.annualFee) annual fee posts \(dateText) (\(when)). Time to review keep, downgrade, or cancel.",
                threadID: card.id,
                payload: ["cardID": card.id]
            ))
        }
        return planned
    }
}
