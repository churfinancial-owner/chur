//
//  BenefitDatabase_Mapping.swift
//  Chur
//
//  Created by Pak Ho on 3/9/26.
//
//  Extension for data transformation. Contains JSON Decodable
//  shapes and mapping logic to translate raw JSON into Templates.

import Foundation

// MARK: - JSON Mapping Logic
extension BenefitDatabase {
    
    static func convertBenefit(_ b: _BenefitJSON, formatter: ISO8601DateFormatter) -> BenefitTemplate {
        let nameEN = b.localized?["en"]?.name ?? b.id
        let descriptionEN = b.localized?["en"]?.description ?? ""
        
        return BenefitTemplate(
            id: b.id,
            benefitType: b.benefitType,
            displayGroup: b.displayGroup,
            nameEN: nameEN,
            nameZH_Hans: b.localized?["zh-Hans"]?.name ?? b.nameZH_Hans,
            nameZH_HK: b.localized?["zh-Hant-HK"]?.name ?? b.nameZH_HK,
            nameZH_TW: b.localized?["zh-Hant-TW"]?.name ?? b.nameZH_TW,
            descriptionEN: descriptionEN,
            descriptionZH_Hans: b.localized?["zh-Hans"]?.description ?? b.descriptionZH_Hans,
            descriptionZH_HK: b.localized?["zh-Hant-HK"]?.description ?? b.descriptionZH_HK,
            descriptionZH_TW: b.localized?["zh-Hant-TW"]?.description ?? b.descriptionZH_TW,
            value: b.value,
            valueCurrency: b.valueCurrency,
            frequency: b.frequency,
            isRecurring: b.isRecurring,
            isActive: b.isActive ?? true,
            activeFromDate: b.activeFromDate.flatMap { formatter.date(from: $0) },
            activeToDate: b.activeToDate.flatMap { formatter.date(from: $0) },
            activationDelayPeriods: b.activationDelayPeriods,
            resetType: b.resetType ?? "calendar",
            usageLimit: b.usageLimit,
            calendarMonthOverrides: b.calendarMonthOverrides.map { dict in
                Dictionary(uniqueKeysWithValues: dict.compactMap { k, v in Int(k).map { ($0, v) } })
            },
            validCountries: b.validCountries,
            excludedCountries: b.excludedCountries,
            trackingMode: b.trackingMode ?? "manual",
            activationMode: b.activationMode ?? (b.requiresActivation == true ? "lockonce" : "unlock"),
            activationInstructions: b.activationInstructions,
            partnerName: b.partnerName,
            partnerID: b.partnerID,
            redemptionMethod: b.redemptionMethod,
            limitDescription: b.limitDescription,
            referenceLink: b.referenceLink,
            benefitNotes: b.benefitNotes,
            displayOrder: b.displayOrder ?? 0,
            iconName: b.iconName
        )
    }

    static func convertLegacyBenefit(_ b: _BenefitJSON, formatter: ISO8601DateFormatter) -> BenefitTemplate {
        // Reuse mapping logic but prioritize flat fields
        return convertBenefit(b, formatter: formatter)
    }

    static func parseJSON<T: Codable>(from filename: String) -> T? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Private JSON Shapes
struct _BenefitJSON: Codable {
    let id: String
    let benefitType: String
    let displayGroup: String
    let localized: [String: BenefitLocalizedStrings]?
    let nameEN: String?; let nameZH_Hans: String?; let nameZH_HK: String?; let nameZH_TW: String?
    let descriptionEN: String?; let descriptionZH_Hans: String?; let descriptionZH_HK: String?; let descriptionZH_TW: String?
    let value: Int
    let valueCurrency: String
    let frequency: String
    let isRecurring: Bool
    let usageLimit: Int?
    let calendarMonthOverrides: [String: Int]?
    let validCountries: [String]?
    let excludedCountries: [String]?
    let trackingMode: String?
    let isActive: Bool?
    let activeFromDate: String?
    let activeToDate: String?
    let activationDelayPeriods: Int?
    let resetType: String?
    let activationMode: String? // "unlock", "lockonce", "lockbyfrequency"
    let requiresActivation: Bool? // Backward compat: true maps to "lockonce" if activationMode absent
    let activationInstructions: String?
    let partnerName: String?
    let partnerID: String?
    let redemptionMethod: String?
    let limitDescription: String?
    let referenceLink: String?
    let benefitNotes: String?
    let displayOrder: Int?
    let iconName: String?
}

struct BenefitLocalizedStrings: Codable {
    let name: String
    let description: String
}
