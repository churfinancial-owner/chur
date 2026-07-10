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

extension Benefit {
    var displayName: String {
        for key in localePriorityKeys {
            if let s = localized[key] { return s.name }
        }
        return localized["en"]?.name ?? id
    }

    var displayDescription: String {
        for key in localePriorityKeys {
            if let s = localized[key] { return s.description }
        }
        return localized["en"]?.description ?? ""
    }

    private var localePriorityKeys: [String] {
        let lang = Locale.current.language.languageCode?.identifier
        let region = Locale.current.region?.identifier
        guard lang == "zh" else { return ["en"] }
        switch region {
        case "HK": return ["zh-Hant-HK", "zh-Hant", "zh", "en"]
        case "TW": return ["zh-Hant-TW", "zh-Hant", "zh", "en"]
        default:   return ["zh-Hans", "zh", "en"]
        }
    }
}
