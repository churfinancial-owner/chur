//
//  Benefit.swift
//  Chur
//
//  Created by Pak Ho on 1/17/26.
//

import Foundation
import SwiftData

// MARK: - Benefit Model
@Model
class Benefit {
    var id: String
    
    // Backend categorization (flexible string)
    var benefitType: String // "credit", "insurance", "lounge_access", "protection", "voucher", etc.
    
    // UI display grouping
    var displayGroup: String // "travel", "dining", "lifestyle", "protection", "membership"
    
    // Localized content (nested structure)
    var localized: [String: LocalizedStrings]
    
    // Value & Currency
    var value: Int // Dollar amount (0 for non-monetary benefits)
    var valueCurrency: String // "USD", "HKD", "TWD", "CAD"
    
    // Optional per-calendar-month overrides for per-period budget (keys: 1 = Jan ... 12 = Dec)
    var calendarMonthOverrides: [Int: Int]?
    
    // Frequency System
    var frequency: String // "one-time", "monthly", "quarterly", "semi-annual", "annual", "quadrennial", "ongoing"
    var isRecurring: Bool // Does it reset? (true for periodic benefits, false for one-time/ongoing)
    var resetType: String = "calendar" // "calendar" or "card_anniversary"
    
    // Usage Tracking
    var usageLimit: Int? // Maximum uses per period (nil = value-based, -1 = unlimited count-based)
    
    // Geographic Restrictions (NEW)
    var validCountries: [String]? // Countries where benefit is valid (nil = worldwide)
    var excludedCountries: [String]? // Countries where benefit is NOT valid
    
    // Auto-Apply System (NEW)
    var trackingMode: String = "manual" // "manual" or "auto" or "recurring"
    var autoApplyUntil: Date? // End date for auto-application
    var autoApplyEnabled: Bool = false // User opted into auto-apply
    
    // Expiration
    var expirationDate: Date? // Hard deadline for the benefit itself
    
    // Partner & Redemption Info
    var partnerName: String? // "Priority Pass", "Uber", "Plaza Premium"
    var partnerID: String? // Link to partner/merchant database
    var redemptionMethod: String? // "automatic", "statement_credit", "portal_booking", "call_concierge", "mobile_app"
    var limitDescription: String? // "Up to 6 visits/year", "Max $600 per claim"
    var referenceLink: String? // URL to benefit details page (e.g. issuer's website)
    
    // Display & Notes
    var benefitNotes: String? // Important callouts
    var displayOrder: Int // Sort order within displayGroup
    var iconName: String? // Custom icon identifier
    
    // Visibility Control
    var isActive: Bool // Master toggle: show/hide benefit
    var activeFromDate: Date? // Benefit becomes visible/available on this date (nil = no start constraint)
    var activeToDate: Date? // Benefit stops being visible/available on this date (nil = no end constraint)
    var activationDelayPeriods: Int? // Number of periods that must pass before benefit becomes available (nil = no delay)

    // Activation Gate
    var activationMode: String = "unlock" // "unlock" (no gate), "lockonce" (one-time activation), "lockbyfrequency" (re-activate each period)
    var activationInstructions: String? // e.g. "Enroll via the CLEAR website"
    var isActivatedByUser: Bool = false // Permanent unlock flag for "lockonce" mode
    var activatedAt: Date? // When user last activated — used by "lockbyfrequency" to check current period

    // Usage History
    @Relationship(deleteRule: .cascade) var usageHistory: [BenefitUsageRecord] = []

    // Lightweight typed access to frequency while keeping `frequency` as the main data field
    enum BenefitFrequency: String {
        case monthly
        case quarterly
        case semiAnnual = "semi-annual"
        case annual
        case quadrennial
        case oneTime = "one-time"
        case ongoing
    }
        
    init(id: String, benefitType: String, displayGroup: String,
         localized: [String: LocalizedStrings],
         value: Int = 0, valueCurrency: String = "USD",
         calendarMonthOverrides: [Int: Int]? = nil,
         frequency: String, isRecurring: Bool, resetType: String = "calendar",
         // Usage Tracking
         usageLimit: Int? = nil,
         // Geographic Restrictions
         validCountries: [String]? = nil, excludedCountries: [String]? = nil,
         // Auto-Apply System
         trackingMode: String = "manual", autoApplyUntil: Date? = nil, autoApplyEnabled: Bool = false,
         // Expiration & Partner Info
         expirationDate: Date? = nil,
         partnerName: String? = nil, partnerID: String? = nil,
         redemptionMethod: String? = nil, limitDescription: String? = nil, referenceLink: String? = nil,
         // Display & Visibility Control
         benefitNotes: String? = nil, displayOrder: Int = 0, iconName: String? = nil,
         isActive: Bool = true, activeFromDate: Date? = nil, activeToDate: Date? = nil,
         activationDelayPeriods: Int? = nil,
         activationMode: String = "unlock", activationInstructions: String? = nil) {
        
        self.id = id
        self.benefitType = benefitType
        self.displayGroup = displayGroup
        self.localized = localized
        self.value = value
        self.valueCurrency = valueCurrency
        self.calendarMonthOverrides = calendarMonthOverrides
        self.frequency = frequency
        self.isRecurring = isRecurring
        self.resetType = resetType
        self.usageLimit = usageLimit
        self.validCountries = validCountries
        self.excludedCountries = excludedCountries
        self.trackingMode = trackingMode
        self.autoApplyUntil = autoApplyUntil
        self.autoApplyEnabled = autoApplyEnabled
        self.expirationDate = expirationDate
        self.partnerName = partnerName
        self.partnerID = partnerID
        self.redemptionMethod = redemptionMethod
        self.limitDescription = limitDescription
        self.referenceLink = referenceLink
        self.benefitNotes = benefitNotes
        self.displayOrder = displayOrder
        self.iconName = iconName
        self.isActive = isActive
        self.activeFromDate = activeFromDate
        self.activeToDate = activeToDate
        self.activationDelayPeriods = activationDelayPeriods
        self.activationMode = activationMode
        self.activationInstructions = activationInstructions
    }
}

