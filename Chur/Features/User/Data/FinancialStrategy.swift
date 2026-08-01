//
//  FinancialStrategy.swift
//  Chur
//
//  Created by Pak Ho.
//

import SwiftUI

enum FinancialStrategy: String, CaseIterable, Identifiable {
    case jetsetter
    case hotelhopper
    case foodie
    case sceneseeker
    case bonuschaser
    case cashking
    case optimizer
    case boss
    case guardian
    case loyalist
    case debtcrusher
    case builder
    
    var id: String { rawValue }
    
    var emoji: String {
        switch self {
        case .jetsetter:    return "✈️"
        case .hotelhopper:  return "🏨"
        case .foodie:       return "🍽️"
        case .sceneseeker:  return "🎟️"
        case .bonuschaser:  return "🎁"
        case .cashking:     return "💵"
        case .optimizer:    return "💡"
        case .boss:         return "💼"
        case .debtcrusher:  return "🚫"
        case .guardian:     return "🛡️"
        case .loyalist:     return "💖"
        case .builder:      return "🔨"
        }
    }
    
    var displayName: String {
        switch self {
        case .jetsetter:    return String(localized: "Jetsetter")
        case .hotelhopper:  return String(localized: "Hotel Hopper")
        case .foodie:       return String(localized: "Foodie")
        case .sceneseeker:  return String(localized: "Scene Seeker")
        case .bonuschaser:  return String(localized: "Bonus Chaser")
        case .cashking:     return String(localized: "Cash King")
        case .optimizer:    return String(localized: "Optimizer")
        case .boss:         return String(localized: "The Boss")
        case .debtcrusher:  return String(localized: "Debt Crusher")
        case .guardian:     return String(localized: "Guardian")
        case .loyalist:     return String(localized: "Loyalist")
        case .builder:      return String(localized: "Credit Build")

        }
    }

    var tagline: String {
        switch self {
        case .jetsetter:    return String(localized: "Flights and miles")
        case .hotelhopper:  return String(localized: "Stays, upgrades & suites")
        case .foodie:       return String(localized: "Dining, takout & experiences")
        case .sceneseeker:  return String(localized: "Shows, movies & events")
        case .bonuschaser:  return String(localized: "Welcome offers & big wins")
        case .cashking:     return String(localized: "Pure cash back, no hassle")
        case .optimizer:    return String(localized: "Everyday, every spend")
        case .boss:         return String(localized: "Scale spend & business perks")
        case .debtcrusher:  return String(localized: "Balance control & Low APR")
        case .guardian:     return String(localized: "Travel & Purchase Protection")
        case .loyalist:     return String(localized: "Brand loyal & exclusive perks")
        case .builder:      return String(localized: "Step-by-step credit growth")
        }
    }
    
    /// Signature color for gradient backgrounds and polaroid accents
    var color: Color {
        switch self {
        case .jetsetter:
            return Color(red: 0.30, green: 0.56, blue: 0.86) // Sky blue
        case .hotelhopper:
            return Color(red: 0.68, green: 0.40, blue: 0.60) // Slightly deeper plum
        case .foodie:
            return Color(red: 0.92, green: 0.45, blue: 0.30) // Slightly warmer
        case .sceneseeker:
            return Color(red: 0.85, green: 0.25, blue: 0.65) //
        case .bonuschaser:
            return Color(red: 0.50, green: 0.78, blue: 0.38) // Brighter green
        case .cashking:
            return Color(red: 0.30, green: 0.68, blue: 0.50) // Slightly deeper mint
        case .optimizer:
            return Color(red: 0.95, green: 0.60, blue: 0.20) // CHANGE → orange
        case .boss:
            return Color(red: 0.12, green: 0.15, blue: 0.20)
        case .debtcrusher:
            return Color(red: 0.38, green: 0.50, blue: 0.65) // Keep steel blue
        case .guardian:
            return Color(red: 0.80, green: 0.60, blue: 0.25) // Slightly deeper gold
        case .loyalist:
            return Color(red: 0.40, green: 0.20, blue: 0.45) //
        case .builder:
            return Color(red: 0.80, green: 0.80, blue: 0.80) //

        }
    }
    
    static let maxSelections = 4
    
    /// Maps each Financial Aura to its corresponding card recommendation category.
    /// Used by the recommendation engine to pick the best `categoryHighlights` punchline.
    var cardCategory: String {
        switch self {
        case .jetsetter:    return "travel"
        case .hotelhopper:  return "hotel"
        case .foodie:       return "dining"
        case .sceneseeker:  return "entertainment"
        case .bonuschaser:  return "signupbonus"
        case .cashking:     return "cashback"
        case .optimizer:    return "everyday"
        case .boss:         return "business"
        case .debtcrusher:  return "lowAPR"
        case .guardian:     return "protection"
        case .loyalist:     return "loyalty"
        case .builder:      return "building"

        }
    }
}
