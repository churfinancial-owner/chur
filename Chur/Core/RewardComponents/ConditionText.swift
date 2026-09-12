//
//  ConditionText.swift
//  Chur
//
//  P1f part 4. Turns a `LayerCondition` — a spend gate or a cap — into the one
//  line of small print that describes it.
//
//  **These are display only.** The app tracks no spend and has no bank feed, so
//  a gate never switches a reward off and a cap never reduces one; the engine
//  prices as if every enrolled bonus is earning, and this text lets the reader
//  judge. Structured rather than free prose so one authored value renders in all
//  four languages and a later phase could act on it without a JSON migration.
//
//  One formatter, three call sites (earning-rate rows, the Bonus Programs
//  section, the tier rows in the picker), so the wording cannot drift.
//

import Foundation

enum ConditionText {

    // MARK: - Public

    /// "Spend HK$3,000 a month to unlock" — the condition that switches a bonus on.
    static func gate(_ condition: LayerCondition?) -> String? {
        guard let condition else { return nil }
        if let note = condition.note, condition.amount == nil { return note }
        guard let amount = condition.amount else { return nil }

        let spend = AppLocale.string("Spend") + " " + money(amount, currency: condition.currency)
        let line = [spend, periodPhrase(condition.period), AppLocale.string("to unlock")]
            .compactMap { $0 }
            .joined(separator: " ")
        return append(note: condition.note, to: line)
    }

    /// "Up to HK$10,000 a month" (spend) or "Up to HK$500 back a month" (reward),
    /// plus a shared-pool note when the condition names a `group`.
    static func cap(_ condition: LayerCondition?, sharedWith otherNames: [String] = []) -> String? {
        guard let condition else { return nil }
        if let note = condition.note, condition.amount == nil { return note }
        guard let amount = condition.amount else { return nil }

        let isReward = condition.kind == "reward"
        let head = AppLocale.string("Up to") + " " + money(amount, currency: condition.currency)
        var line = [head, isReward ? AppLocale.string("back") : nil, periodPhrase(condition.period)]
            .compactMap { $0 }
            .joined(separator: " ")

        if !otherNames.isEmpty {
            line += " · " + AppLocale.string("shares this cap with") + " " + otherNames.joined(separator: ", ")
        }
        return append(note: condition.note, to: line)
    }

    /// Both lines a row can carry, in reading order.
    static func lines(gate gateCondition: LayerCondition?, cap capCondition: LayerCondition?, sharedWith otherNames: [String] = []) -> [String] {
        [gate(gateCondition), cap(capCondition, sharedWith: otherNames)].compactMap { $0 }
    }

    /// "HK$200 per redemption" — a bank's handling fee for moving points out.
    /// Display only, for the same reason gates and caps are: what it costs per
    /// mile depends on how many points move, which the app does not know.
    static func transferFee(_ fee: TransferFee?) -> String? {
        guard let fee else { return nil }
        // A card that has the fee waived says so, rather than showing "HK$0".
        guard fee.amount > 0 else {
            return fee.note ?? AppLocale.string("No transfer fee")
        }
        let basis: String
        switch fee.resolvedBasis {
        case "transaction": basis = AppLocale.string("per transaction")
        default:            basis = AppLocale.string("per redemption")
        }
        let line = money(fee.amount, currency: fee.currency) + " " + basis
        return append(note: fee.note, to: line)
    }

    // MARK: - Pieces

    /// `HK$3,000`. The symbol comes from the regions seed by currency code, so a
    /// cap authored in HKD reads as HK$ wherever the user is.
    static func money(_ amount: Double, currency: String?) -> String {
        let symbol = symbol(for: currency)
        let rounded = amount.rounded()
        let digits = abs(amount - rounded) < 0.005 ? 0 : 2
        let formatted = amount.formatted(.number.precision(.fractionLength(digits)).grouping(.automatic))
        return symbol + formatted
    }

    private static func symbol(for currency: String?) -> String {
        guard let currency else { return "$" }
        let code = CurrencyConversion.normalized(currency)
        // The regions seed is keyed by country, so find the region using this currency.
        if let region = RegionDatabase.allRegions.first(where: { CurrencyConversion.normalized($0.currency) == code }) {
            return region.currencySymbol
        }
        return code + " "
    }

    /// "a month", "a statement cycle", "a year" — nil for an unstated period.
    private static func periodPhrase(_ period: String?) -> String? {
        switch period {
        case "calendarMonth":  return AppLocale.string("a month")
        case "statementCycle": return AppLocale.string("a statement cycle")
        case "quarter":        return AppLocale.string("a quarter")
        case "halfYear":       return AppLocale.string("every six months")
        case "year":           return AppLocale.string("a year")
        case "promo":          return AppLocale.string("for the promotion")
        default:               return nil
        }
    }

    private static func append(note: String?, to line: String) -> String {
        guard let note, !note.isEmpty else { return line }
        return line + " · " + note
    }
}
