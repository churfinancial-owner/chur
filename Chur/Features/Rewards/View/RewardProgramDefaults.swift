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
    /// How a rate on this program reads (P1f part 4). Display only — the maths is
    /// always `rate × pointCashValue`.
    var rateStyle: RateStyle = .multiplier
}

/// `3x` (default), `3%` for HK cash-back programs, or `HK$3 = 1 mile` for miles
/// programs quoted that way in the market.
enum RateStyle: String, Codable {
    case multiplier
    case percent
    case perMile
}

// MARK: - Reward Program Defaults Loader

struct RewardProgramDefaults {

    private struct _JSON: Codable {
        let pointCashValue: Double
        let currency: String
        let rateStyle: RateStyle?
    }

    /// Default point values keyed by reward program name.
    ///
    /// A `var` since P1d, for the same reason as BoostProgramDatabase.all: this
    /// publishes remotely, and a `let` resolves once on first access — so a
    /// refresh landing mid-session would leave every point value at the value
    /// the build shipped with until relaunch. These are dollars.
    private(set) static var all: [String: RewardProgramDefault] = load()

    static func reloadFromBundle() {
        all = load()
    }

    private static func load() -> [String: RewardProgramDefault] {
        let map: [String: _JSON]
        if let remote: [String: _JSON] = RemoteSeed.decode(.programs, label: "RewardProgramDefaults"),
           !remote.isEmpty {
            map = remote
        } else if let url = Bundle.main.url(forResource: "SeedDataPrograms", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode([String: _JSON].self, from: data) {
            map = decoded
        } else {
            return [:]
        }

        return map.mapValues {
            RewardProgramDefault(
                pointCashValue: $0.pointCashValue,
                currency: $0.currency,
                rateStyle: $0.rateStyle ?? .multiplier
            )
        }
    }

    static func defaultValue(for programName: String) -> RewardProgramDefault? {
        all[programName]
    }

    /// Returns true if the given pointCashValue matches the default for this program
    static func isDefault(programName: String, pointCashValue: Double) -> Bool {
        guard let def = defaultValue(for: programName) else { return false }
        return abs(def.pointCashValue - pointCashValue) < 0.000001
    }
}
