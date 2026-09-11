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

    /// The rate as the program quotes it (P1f part 4): `3x`, `3%`, or `HK$3 = 1 mile`.
    /// `currency` is the program's, for the per-mile form only.
    func formatAsRate(style: RateStyle, currency: String? = nil) -> String {
        switch style {
        case .multiplier:
            return formatAsRate()
        case .percent:
            return formatted(.number.precision(.fractionLength(0...2))) + "%"
        case .perMile:
            guard self > 0 else { return "-" }
            let perMile = 1 / self
            return ConditionText.money(perMile, currency: currency) + " = 1 " + AppLocale.string("mile")
        }
    }

    /// Convenience: the style and currency resolved from a reward program name.
    func formatAsRate(program: String?) -> String {
        guard let program, let defaults = RewardProgramDefaults.defaultValue(for: program) else {
            return formatAsRate()
        }
        return formatAsRate(style: defaults.rateStyle, currency: defaults.currency)
    }
}
