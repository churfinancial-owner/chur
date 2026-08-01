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
        AppLocale.localePriorityKeys(for: AppLocale.current)
    }
}
