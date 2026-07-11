//
//  ReminderScheduler_AnnualFee.swift
//  Chur
//
//  Annual fee reminder planner. The fee date is the card's anniversary
//  (approvedMonth/approvedDay each year). Lead time is user-configurable
//  (ReminderTiming.annualFeeLeadDays, default 30 days) plus a fixed
//  7-day last call. Cards with a $0 fee never remind — downgrading a
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

            for lead in ReminderTiming.annualFeeReminderDays() {
                guard let fireDate = Self.deliveryDate(daysBefore: lead, deadline: feeDate),
                      fireDate > now else { continue }

                planned.append(PlannedReminder(
                    identifier: "\(Self.identifierPrefix)fee.\(card.id).\(feeYear).\(lead)d",
                    kind: .annualFee,
                    fireDate: fireDate,
                    title: card.name,
                    subtitle: "Annual fee",
                    body: "\(symbol)\(card.annualFee) annual fee posts \(dateText) (in \(lead) days). Time to review keep, downgrade, or cancel.",
                    threadID: card.id,
                    payload: ["cardID": card.id]
                ))
            }
        }
        return planned
    }
}
