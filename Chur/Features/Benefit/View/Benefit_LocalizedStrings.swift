//
//  Benefit_LocalizedStrings.swift
//  Chur
//
//  Created by Pak Ho on 3/13/26.
//

import Foundation

// MARK: - Localized Strings Structure
struct LocalizedStrings: Codable, Equatable {
    var name: String
    var description: String
}

// Computed property for display name

extension Benefit {
    var displayName: String {
        let languageCode = Locale.current.language.languageCode?.identifier
        let regionCode = Locale.current.region?.identifier
        
        // Build locale key priority list
        var localeKeys: [String] = []
        
        if languageCode == "zh" {
            if regionCode == "HK" {
                localeKeys = ["zh-Hant-HK", "zh-Hant", "zh", "en"]
            } else if regionCode == "TW" {
                localeKeys = ["zh-Hant-TW", "zh-Hant", "zh", "en"]
            } else {
                localeKeys = ["zh-Hans", "zh", "en"]
            }
        } else {
            localeKeys = ["en"]
        }
        
        // Try each locale key in priority order
        for key in localeKeys {
            if let localizedString = localized[key] {
                return localizedString.name
            }
        }
        
        // Fallback to English if available
        return localized["en"]?.name ?? id
    }
    
    // Computed property for display description
    var displayDescription: String {
        let languageCode = Locale.current.language.languageCode?.identifier
        let regionCode = Locale.current.region?.identifier
        
        // Build locale key priority list
        var localeKeys: [String] = []
        
        if languageCode == "zh" {
            if regionCode == "HK" {
                localeKeys = ["zh-Hant-HK", "zh-Hant", "zh", "en"]
            } else if regionCode == "TW" {
                localeKeys = ["zh-Hant-TW", "zh-Hant", "zh", "en"]
            } else {
                localeKeys = ["zh-Hans", "zh", "en"]
            }
        } else {
            localeKeys = ["en"]
        }
        
        // Try each locale key in priority order
        for key in localeKeys {
            if let localizedString = localized[key] {
                return localizedString.description
            }
        }
        
        // Fallback to English if available
        return localized["en"]?.description ?? ""
    }
}
