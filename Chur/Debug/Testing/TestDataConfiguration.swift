//
//  TestDataConfiguration.swift
//  Chur
//
//  Created by Pak Ho on 2/2/26.
//
//  Centralized configuration for all test/seed data used during development.
//  This makes it easy to find and modify test data in one place.

import Foundation

struct TestDataConfiguration {
    
    // MARK: - Test User Configuration
    
    struct TestUser {
        static let firstName = "Ho Ho Test"
        static let email = "testuser@gmail.com"
        static let appleUserID = "Testuserid"
        static let googleUserID = ""
        static let profileEmoji = "😊"
        static let onboardingCompleted = true
        static let selectedCategories: [String] = []
        static let authProvider = "apple"
    }
    
    // MARK: - JSON Seed Files
    
    /// Names of JSON files used to seed the app
    struct SeedFiles {
        static let categories = "SeedDatacategories"
        static let cards = "SeedDatacards"
        static let rewards = "SeedDatarewards"
        static let benefits = "SeedDatabenefits"
    }
    
    // MARK: - Starter Cards (Optional)
    
    static let starterCardIDs: [String] = [
    ]
    
    
    // MARK: - Time Travel (Testing)
    
    #if DEBUG
    /// Override the current date for testing time-dependent logic (nil = use real date)
    static var mockCurrentDate: Date? = nil
    
    /// Helper to create test dates
    static func setMockDate(year: Int, month: Int, day: Int, hour: Int = 12) {
        mockCurrentDate = Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))
        notifyDateChanged()
    }
    
    /// Reset to real time
    static func resetToRealTime() {
        mockCurrentDate = nil
        notifyDateChanged()
    }
    
    /// Posts a notification so subscribed views re-evaluate Date.current().
    static func notifyDateChanged() {
        NotificationCenter.default.post(name: .timeTravelDateChanged, object: nil)
    }
    #endif
    
    // MARK: - Development Flags
    
    /// Enable/disable test data initialization
    static let enableTestUser = true
    
    /// Enable/disable seed data loading
    static let loadSeedCategories = true
    
    /// Enable diagnostic logging
    static let enableDiagnosticLogging = true
    
    /// Enable debug button to reset data (for testing)
    /// Shows a trash icon in the Search tab to trigger data reset
    static let enableDevelopmentGestures = true
}
// MARK: - Notification Name

#if DEBUG
extension Notification.Name {
    static let timeTravelDateChanged = Notification.Name("timeTravelDateChanged")
}
#endif

