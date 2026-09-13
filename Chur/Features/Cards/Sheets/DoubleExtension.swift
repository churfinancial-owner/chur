//
//  DoubleExtension.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import Foundation

extension Double {
    func formatAsRate() -> String {
        return self.formatted(.number.precision(.fractionLength(0...2))) + "x"
    }

    /// The rate as the program quotes it (P1f part 4): `3x`, `3%`, or `HK$2/mile`.
    /// `currency` is the program's, for the per-mile form only.
    ///
    /// Each style says one thing, the way its own market quotes it. `perMile` used
    /// to pair the cost with its percentage — `2.54% (HK$4/mile)` — which made it
    /// the only style that also answered the effective-rate question, and made a
    /// miles card read differently from a points card for no reason a user could
    /// see. A `3x` does not explain what a point is worth either; that is what the
    /// effective rate is for.
    func formatAsRate(style: RateStyle, currency: String? = nil) -> String {
        switch style {
        case .multiplier:
            return formatAsRate()
        case .percent:
            return formatted(.number.precision(.fractionLength(0...2))) + "%"
        case .perMile:
            guard self > 0 else { return formatAsRate() }
            return ConditionText.money(1 / self, currency: currency) + "/" + AppLocale.string("mile")
        }
    }

    /// Convenience: the style, currency and point value resolved from a reward
    /// program name. `perMile` only applies when the points can actually become
    /// miles: either the program has transfer partners, or it *is* a miles
    /// currency (`milesCurrency`, e.g. Asia Miles HK, which needs no transfer).
    /// A Freedom therefore reads as a plain rate until a Sapphire upgrades its
    /// program. The fallback is `multiplier`, not `percent`: a perMile program's
    /// rate is miles per dollar, so printing it with a `%` would assert a cash
    /// rate the number is not.
    func formatAsRate(program: String?) -> String {
        guard let program, let defaults = RewardProgramDefaults.defaultValue(for: program) else {
            return formatAsRate()
        }
        var style = defaults.rateStyle
        if style == .perMile, !defaults.milesCurrency,
           TransferPartnerDatabase.program(named: program) == nil {
            style = .multiplier
        }
        return formatAsRate(style: style, currency: defaults.currency)
    }
}
