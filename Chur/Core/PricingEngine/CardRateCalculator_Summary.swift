//
//  CardRateCalculator_Summary.swift
//  Chur
//
//  Created by Pak Ho on 3/18/26.
//
// This code defines a data structure that stores credit card reward information and automatically formats raw decimals into user-friendly strings like "5%" or "1.25¢/pt". It serves as a "translator" between the app's backend calculations and the visual labels shown to a user on a summary screen.
//

import Foundation

struct CardRateSummary {
    let name: String
    let rate: Double
    let effectiveCashBackRate: Double // e.g. 0.05 = 5% return per dollar spent
    let pointCashValue: Double // e.g. 0.0125 for 1.25¢ per point
    let pointCashValueCurrency: String // e.g. "USD"
    let rewardProgramName: String // e.g. "Ultimate Rewards"
    /// The earning layers that fired for this result (P1f). Empty when none did.
    var boostLayers: [AppliedLayer] = []
    /// The payment method the winning row relied on, if any ("with Apple Pay"). P1f part 3.
    var viaPaymentMethod: String? = nil
    
    /// Formatted display string as percentage, e.g. "5%", "9.75%", "-1.25%"
    var effectiveRateDisplayString: String {
        let pct = effectiveCashBackRate * 100
        if pct.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(String(format: "%.0f", pct))%"
        } else if (pct * 10).truncatingRemainder(dividingBy: 1) == 0 {
            return "\(String(format: "%.1f", pct))%"
        } else {
            return "\(String(format: "%.2f", pct))%"
        }
    }
    
    /// Point value in cents of its own currency, e.g. "1.25¢ USD", "10.15¢ HKD".
    ///
    /// The currency is named because the cent symbol alone is ambiguous once more
    /// than one market is in the app: Asia Miles at HK$0.1015 read as "10.15¢",
    /// which is an entirely believable — and entirely wrong — US figure.
    var pointValueDisplayString: String {
        let cents = pointCashValue * 100
        let amount: String
        if cents.truncatingRemainder(dividingBy: 1) == 0 {
            amount = String(format: "%.0f", cents)
        } else if (cents * 10).truncatingRemainder(dividingBy: 1) == 0 {
            amount = String(format: "%.1f", cents)
        } else {
            amount = String(format: "%.2f", cents)
        }
        return amount + "¢ " + CurrencyConversion.normalized(pointCashValueCurrency)
    }
}
