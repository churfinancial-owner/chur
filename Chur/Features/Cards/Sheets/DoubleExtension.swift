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
    func formatAsRate(style: RateStyle, currency: String? = nil, pointCashValue: Double? = nil) -> String {
        switch style {
        case .multiplier:
            return formatAsRate()
        case .percent:
            return formatted(.number.precision(.fractionLength(0...2))) + "%"
        case .perMile:
            // The paired form HK cards are quoted in: "4% (HK$2.5/里)". The
            // percentage stays first because it is what the engine ranks on.
            guard self > 0, let pointCashValue else { return formatAsRate() }
            let percent = (self * pointCashValue * 100).formatted(.number.precision(.fractionLength(0...2)))
            let perMile = ConditionText.money(1 / self, currency: currency)
            return "\(percent)% (\(perMile)/\(AppLocale.string("mile")))"
        }
    }

    /// Convenience: the style, currency and point value resolved from a reward
    /// program name. `perMile` only applies when that program actually has
    /// transfer partners — a card whose points stay put reads as a plain rate,
    /// and a Freedom reads that way until a Sapphire upgrades its program.
    func formatAsRate(program: String?) -> String {
        guard let program, let defaults = RewardProgramDefaults.defaultValue(for: program) else {
            return formatAsRate()
        }
        var style = defaults.rateStyle
        if style == .perMile, TransferPartnerDatabase.program(named: program) == nil {
            style = .percent
        }
        return formatAsRate(style: style, currency: defaults.currency, pointCashValue: defaults.pointCashValue)
    }
}
