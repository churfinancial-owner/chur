//
//  CurrencyConversion.swift
//  Chur
//
//  Static conversion table for cross-currency effective rate comparison.
//  Converts effective rates (cents-per-local-dollar) between supported currencies.
//

import Foundation

enum CurrencyConversion {

    // MARK: - Country → Currency mapping

    /// Maps a user country code (e.g. "US", "CA", "HK") to its ISO 4217 currency code.
    static func currencyCode(forCountry country: String) -> String {
        RegionDatabase.currencyCode(for: country)
    }

    /// Currency of a merchant region (P1f part 3). The regions seed covers the
    /// launch markets; anywhere else falls back to the platform's ISO table so a
    /// Tokyo restaurant resolves to JPY without a seed entry. "UK" is the seed's
    /// spelling; ISO wants "GB".
    static func currencyCode(forRegion region: String) -> String {
        let code = region.uppercased()
        if RegionDatabase.byID[code] != nil { return normalized(RegionDatabase.currencyCode(for: code)) }
        let iso = code == "UK" ? "GB" : code
        if let currency = Locale(identifier: "en_\(iso)").currency?.identifier { return normalized(currency) }
        return "USD"
    }

    // MARK: - Static exchange rates (base: USD)
    // Approximate mid-market rates. Last updated: March 2026.

    /// Exchange rates relative to 1 USD.
    /// rate[X] means: 1 USD = rate[X] units of X.
    private static let ratesPerUSD: [String: Double] = [
        "USD": 1.0,
        "CAD": 1.36,
        "HKD": 7.78,
    ]

    // MARK: - Conversion

    /// Converts an amount from one currency to another.
    /// Returns the original amount if currencies match or are unknown.
    static func convert(_ amount: Double, from source: String, to target: String) -> Double {
        let src = normalized(source)
        let tgt = normalized(target)
        guard src != tgt else { return amount }
        guard let srcRate = ratesPerUSD[src],
              let tgtRate = ratesPerUSD[tgt] else { return amount }
        // amount is in `src` → convert to USD → convert to `tgt`
        return amount / srcRate * tgtRate
    }

    /// Returns the conversion factor from source to target currency.
    /// E.g. conversionFactor(from: "USD", to: "HKD") → 7.78
    static func conversionFactor(from source: String, to target: String) -> Double {
        let src = normalized(source)
        let tgt = normalized(target)
        guard src != tgt else { return 1.0 }
        guard let srcRate = ratesPerUSD[src],
              let tgtRate = ratesPerUSD[tgt] else { return 1.0 }
        return tgtRate / srcRate
    }

    // MARK: - Normalization

    /// Normalizes currency codes, fixing known inconsistencies (e.g. "HKG" → "HKD").
    static func normalized(_ code: String) -> String {
        let upper = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch upper {
        case "HKG": return "HKD"
        default:    return upper
        }
    }
}
