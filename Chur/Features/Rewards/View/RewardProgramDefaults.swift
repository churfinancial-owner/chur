//
//  RewardProgramDefaults.swift
//  Chur
//
//  Created by Pak Ho on 2/13/26.
//

import Foundation

// MARK: - Reward Program Default Value

struct RewardProgramDefault {
    let pointCashValue: Double
    let currency: String
}

// MARK: - Reward Program Defaults Loader

struct RewardProgramDefaults {

    /// Default point values keyed by reward program name, loaded from SeedDataPrograms.json.
    static let all: [String: RewardProgramDefault] = {
        struct _JSON: Codable {
            let pointCashValue: Double
            let currency: String
        }
        guard let url = Bundle.main.url(forResource: "SeedDataPrograms", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode([String: _JSON].self, from: data)
        else { return [:] }

        return map.mapValues { RewardProgramDefault(pointCashValue: $0.pointCashValue, currency: $0.currency) }
    }()

    static func defaultValue(for programName: String) -> RewardProgramDefault? {
        all[programName]
    }

    /// Returns true if the given pointCashValue matches the default for this program
    static func isDefault(programName: String, pointCashValue: Double) -> Bool {
        guard let def = defaultValue(for: programName) else { return false }
        return abs(def.pointCashValue - pointCashValue) < 0.000001
    }
}
