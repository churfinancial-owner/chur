//
//  RateDisplay.swift
//  Chur
//
//  The one place that answers "how does this rate read".
//
//  Before this existed there were eight formatters for two numbers, and they had
//  grown apart: three knew the reward program and three did not, two produced the
//  effective percentage with different rules for zero, and whether the user's
//  Card Rate / Effective Rate preference was honoured depended on the screen. The
//  Hong Kong miles cards made it visible — a rate authored as 0.25 miles per
//  dollar reads as "HK$4/mile" through one path and "0.25x" through another — but
//  the divergence predates them.
//
//  Everything user-facing goes through here. `Double.formatAsRate` is the
//  underlying formatter and is not a call site.
//

import SwiftUI

enum RateDisplay {

    /// Where the number sits, which decides how much of it to print.
    enum Context {
        /// A full-width row with room for the whole form a program quotes:
        /// `5.08% (HK$2/mile)`.
        case standalone
        /// A pill or a chip. A miles program prints the mile cost alone — partly
        /// for room, and partly because these sit next to an effective-rate pill
        /// that is already showing the percentage.
        case compact
        /// Inside `rate × point value = effective`. Prints the raw multiplier,
        /// because that row exists to show the multiplication and the per-mile
        /// form is its reciprocal.
        case formula
    }

    /// Shown wherever a rate has no value to report. One glyph, so a missing rate
    /// looks the same on every screen.
    static let placeholder = "–"

    // MARK: - The card's rate

    /// The rate as its program quotes it: `3x`, `5%`, or `5.08% (HK$2/mile)`.
    static func rate(_ rate: Double, program: String?, context: Context = .standalone) -> String {
        guard rate > 0 else { return placeholder }
        switch context {
        case .standalone: return rate.formatAsRate(program: program)
        case .compact:    return rate.formatAsRate(program: program, compact: true)
        case .formula:    return rate.formatAsRate()
        }
    }

    // MARK: - The effective return

    /// `5.08%`, `-0.95%`, or the placeholder when there is nothing to earn.
    ///
    /// Negatives print rather than collapsing to the placeholder: a rate the FX
    /// fee has eaten is a finding, not a blank. One of the two formatters this
    /// replaced hid them.
    static func effective(_ effectiveRate: Double) -> String {
        guard effectiveRate != 0 else { return placeholder }
        let percent = effectiveRate * 100
        if percent.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f%%", percent)
        }
        if (percent * 10).truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.1f%%", percent)
        }
        return String(format: "%.2f%%", percent)
    }

    // MARK: - Whichever the user asked for

    /// The number the user's Display setting asks for. Passed the preference
    /// rather than reading it, so the decision is visible at the call site and a
    /// screen cannot quietly opt out — which is how the setting came to be
    /// honoured on some screens and not others.
    static func preferred(
        rate: Double,
        effectiveRate: Double,
        program: String?,
        showEffectiveRate: Bool,
        context: Context = .standalone
    ) -> String {
        showEffectiveRate ? effective(effectiveRate) : self.rate(rate, program: program, context: context)
    }

    /// The pill colour for whatever `preferred(...)` just returned. Kept here so
    /// the colour and the text can never disagree about whether there is a number.
    static func pillMode(rate: Double, effectiveRate: Double, showEffectiveRate: Bool) -> RatePill.DisplayMode {
        guard showEffectiveRate else { return rate > 0 ? .points : .empty }
        if effectiveRate == 0 { return .empty }
        return effectiveRate < 0 ? .effectiveNegative : .effectivePositive
    }
}

// MARK: - Summary conveniences

extension CardRateSummary {

    func rateText(context: RateDisplay.Context = .standalone) -> String {
        RateDisplay.rate(rate, program: rewardProgramName, context: context)
    }

    var effectiveText: String {
        RateDisplay.effective(effectiveCashBackRate)
    }

    func preferredText(showEffectiveRate: Bool, context: RateDisplay.Context = .standalone) -> String {
        RateDisplay.preferred(
            rate: rate,
            effectiveRate: effectiveCashBackRate,
            program: rewardProgramName,
            showEffectiveRate: showEffectiveRate,
            context: context
        )
    }
}
