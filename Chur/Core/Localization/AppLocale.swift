//
//  AppLocale.swift
//  Chur
//
//  Single source of truth for locale resolution. UI (.environment(\.locale, ...))
//  and model-content lookups (Benefit, SpendingCategory) both route through this
//  instead of reading Locale.current independently, so a user's language override
//  is never applied to only one of the two.
//

import Foundation

/// The set of languages a user can explicitly select in Settings.
/// `.system` means "no override — follow the device's Locale.current".
enum AppLanguage: String, Codable, CaseIterable {
    case system
    case english
    case chineseHK = "zh-Hant-HK"

    var locale: Locale? {
        switch self {
        case .system: return nil
        case .english: return Locale(identifier: "en")
        case .chineseHK: return Locale(identifier: "zh-Hant-HK")
        }
    }
}

enum AppLocale {
    private static let activeLanguageKey = "appLanguage"

    /// Mirrors `User.languagePreference` in UserDefaults so the active language can be
    /// read synchronously (e.g. at app launch, before a ModelContext/User is available)
    /// without threading a SwiftUI environment value into non-View model code.
    /// `LanguageSettingsView` writes through to this whenever the user changes the
    /// setting; `User.languagePreference` remains the syncable source of truth.
    static var activeLanguage: AppLanguage {
        get {
            UserDefaults.standard.string(forKey: activeLanguageKey)
                .flatMap(AppLanguage.init(rawValue:)) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: activeLanguageKey)
        }
    }

    /// The Locale reflecting the current active language override (or system default).
    static var current: Locale {
        resolve(activeLanguage)
    }

    /// Resolves the effective Locale for a given user override, falling back to
    /// the device locale when the override is `.system`.
    static func resolve(_ override: AppLanguage) -> Locale {
        override.locale ?? Locale.current
    }

    /// The ordered list of localized-content keys to try for a given locale,
    /// e.g. Benefit.localized["zh-Hant-HK"] / SpendingCategory.nameZH_HK.
    /// Shared by Benefit and SpendingCategory so their fallback chains can't diverge.
    static func localePriorityKeys(for locale: Locale) -> [String] {
        let lang = locale.language.languageCode?.identifier
        let region = locale.region?.identifier
        guard lang == "zh" else { return ["en"] }
        switch region {
        case "HK": return ["zh-Hant-HK", "zh-Hant", "zh", "en"]
        case "TW": return ["zh-Hant-TW", "zh-Hant", "zh", "en"]
        default:   return ["zh-Hans", "zh", "en"]
        }
    }
}
