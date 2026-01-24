//
//  User.swift
//  Chur
//
//  Created by Pak Ho on 1/17/26.
//

import Foundation
import SwiftData

// MARK: - User Model
@Model
class User {
    var firstName: String
    var email: String
    var appleUserID: String
    var googleUserID: String
    var onboardingCompleted: Bool
    var notificationsEnabled: Bool
    var locationEnabled: Bool
    var dateAdded: Date
    var selectedCategories: [String]
    var deselectedCategories: [String] // Categories user explicitly unchecked
    var explicitlySelectedParentCategories: [String] // Parent categories user intentionally turned on in picker
    var cardDisplayOrder: [String] // Stores custom card order by card IDs
    var showEffectiveRate: Bool     // Display effective rate (rate × pointCashValue) instead of raw multiplier
    var boostEnrollments: [String: String] // [programID: tierName] e.g. ["bofa-preferred-rewards": "Platinum Honors"]
    var country: String // User's preferred country for card database (e.g., "US", "HK")
    var earningPowerTravelModeEnabled: Bool // Force Earning Power calculations to apply cross-border FX fee logic
    var profilePhotoData: Data? // Profile photo stored as compressed JPEG
    var profileEmoji: String // Emoji avatar for the user profile
    var authProvider: String // "apple", "google", or "anonymous"
    var strategyPreferences: [String] // Financial Aura selections e.g. ["jetsetter", "socialite"]
    
    init(firstName: String, email: String, appleUserID: String) {
        self.firstName = firstName
        self.email = email
        self.appleUserID = appleUserID
        self.googleUserID = ""
        self.onboardingCompleted = false
        self.notificationsEnabled = false
        self.locationEnabled = false
        self.dateAdded = Date()
        self.selectedCategories = []
        self.deselectedCategories = []
        self.explicitlySelectedParentCategories = []
        self.cardDisplayOrder = []
        self.showEffectiveRate = false
        self.boostEnrollments = [:]
        self.earningPowerTravelModeEnabled = false
        self.profilePhotoData = nil
        self.profileEmoji = "😊"
        self.authProvider = "anonymous"
        self.strategyPreferences = []
        
        // Default country based on user's locale
        self.country = Self.detectUserCountry()
    }
    
    /// Detects the user's country based on their device locale
    static func detectUserCountry() -> String {
        RegionDatabase.detectUserRegion()
    }
}
