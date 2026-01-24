import Foundation

extension String {
    /// Converts a currency code (e.g. `"USD"`) into its display symbol (e.g. `"$"`).
    /// Used anywhere a benefit's `valueCurrency` needs to be shown in the UI.
    ///
    /// Falls back to the raw currency code followed by a space (e.g. `"MYR "`)
    /// for any unrecognised codes, so new currencies degrade gracefully.
    var currencySymbol: String {
        switch self.uppercased() {
        case "USD":               return "$"
        case "CAD":               return "$"
        case "TWD":               return "$"
        case "HKD":               return "$"
        case "CNY":               return "¥"
        default:                  return self.uppercased() + " "
        }
    }
}
