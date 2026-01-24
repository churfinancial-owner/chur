//
//  BenefitTemplate.swift.swift
//  Chur
//
//  Created by Pak Ho on 3/9/26.
//
//  The static data structure representing a benefit from the JSON catalog.
//  Handles the 'toBenefit' mapping to create SwiftData @Models.

import Foundation
import SwiftData

struct BenefitTemplate {
    let id: String
    let benefitType: String
    let displayGroup: String
    let nameEN: String
    let nameZH_Hans: String?
    let nameZH_HK: String?
    let nameZH_TW: String?
    let descriptionEN: String?
    let descriptionZH_Hans: String?
    let descriptionZH_HK: String?
    let descriptionZH_TW: String?
    let value: Int
    let valueCurrency: String
    let frequency: String
    let isRecurring: Bool
    let isActive: Bool
    let activeFromDate: Date?
    let activeToDate: Date?
    let activationDelayPeriods: Int?
    let resetType: String

    let usageLimit: Int?
    let calendarMonthOverrides: [Int: Int]?
    let validCountries: [String]?
    let excludedCountries: [String]?
    let trackingMode: String
    let activationMode: String
    let activationInstructions: String?

    let partnerName: String?
    let partnerID: String?
    let redemptionMethod: String?
    let limitDescription: String?
    let referenceLink: String?
    let benefitNotes: String?
    let displayOrder: Int
    let iconName: String?

    // MARK: - Helpers
    var displayName: String { nameEN }
    var displayDescription: String { descriptionEN ?? "" }

    func isValidInCountry(_ countryCode: String) -> Bool {
        if let valid = validCountries, !valid.contains(countryCode) { return false }
        if let excluded = excludedCountries, excluded.contains(countryCode) { return false }
        return true
    }

    /// Converts this template into a live SwiftData @Model.
    func toBenefit(cardInstanceID: String, modelContext: ModelContext) -> Benefit {
        var localizedDict: [String: LocalizedStrings] = [:]
        localizedDict["en"] = LocalizedStrings(name: nameEN, description: descriptionEN ?? "")
        
        if let name = nameZH_Hans, let desc = descriptionZH_Hans {
            localizedDict["zh-Hans"] = LocalizedStrings(name: name, description: desc)
        }
        if let name = nameZH_HK, let desc = descriptionZH_HK {
            localizedDict["zh-Hant-HK"] = LocalizedStrings(name: name, description: desc)
        }
        if let name = nameZH_TW, let desc = descriptionZH_TW {
            localizedDict["zh-Hant-TW"] = LocalizedStrings(name: name, description: desc)
        }
        
        let benefit = Benefit(
            id: "\(cardInstanceID)_\(id)",
            benefitType: benefitType,
            displayGroup: displayGroup,
            localized: localizedDict,
            value: value,
            valueCurrency: valueCurrency,
            calendarMonthOverrides: calendarMonthOverrides,
            frequency: frequency,
            isRecurring: isRecurring,
            resetType: resetType,
            usageLimit: usageLimit,
            validCountries: validCountries,
            excludedCountries: excludedCountries,
            trackingMode: trackingMode,
            partnerName: partnerName, partnerID: partnerID,
            redemptionMethod: redemptionMethod, limitDescription: limitDescription, referenceLink: referenceLink,
            benefitNotes: benefitNotes, displayOrder: displayOrder, iconName: iconName,
            isActive: isActive, activeFromDate: activeFromDate, activeToDate: activeToDate,
            activationDelayPeriods: activationDelayPeriods,
            activationMode: activationMode, activationInstructions: activationInstructions
        )

        modelContext.insert(benefit)
        return benefit
    }
}
