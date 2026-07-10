//
//  Colors.swift
//  Chur
//
//  Created by Pak Ho on 1/17/26.
//

import SwiftUI

extension Color {
    // MARK: - Primary Colors
    static let churOlivetext = Color(hex: "5C5A33")
    static let churOliveDark = Color(hex: "434328")
    static let churOliveLight2 = Color(hex: "D4D29B")
    
    // MARK: - Neutrals
    static let churLightGray = Color(hex: "D3D3D3")
    static let churDarkGray = Color(hex: "4A4A4A")
    
    // MARK: - Accents
    static let churSuccess = Color(hex: "7FAA65")
    static let churWarning = Color(hex: "E89C5C")
    static let churError = Color(hex: "D87A7A")
    static let churInfo = Color(hex: "7B9AAF")
    
    // MARK: - Status Tiers (hotel, badge, loyalty programs)
    static let churTierGold    = Color(red: 1.0,  green: 0.84, blue: 0.0)
    static let churTierSilver  = Color(red: 0.75, green: 0.75, blue: 0.78)
    static let churTierBronze  = Color(red: 0.8,  green: 0.5,  blue: 0.2)
    static let churTierDiamond = Color(red: 0.35, green: 0.55, blue: 0.85)

    // MARK: - Coupon Category Colors
    static let churCouponDining        = Color(hex: "E8734A")
    static let churCouponShopping      = Color(hex: "5B8DEF")
    static let churCouponEntertainment = Color(hex: "9B59B6")
    static let churCouponConvenience   = Color(hex: "2ECC71")
    static let churCouponTravel        = Color(hex: "3498DB")
    static let churCouponCheckedBags   = Color(hex: "E67E22")
    static let churCouponBusiness      = Color(hex: "7F8C8D")

    // MARK: - Card Issuers
    static let churChase = Color(hex: "1A4F8B")
    static let churAmex = Color(hex: "006FCF")
    static let churCiti = Color(hex: "003D6A")
    static let churCapitalOne = Color(hex: "DB3D2C")
    static let churBofA = Color(hex: "E31837")
    
    // MARK: - Category Badge Tints
    static let churCategoryDining               = Color(hex: "F6E4DC") // warm peach
    static let churCategoryTravel               = Color(hex: "E5EEF6") // sky blue
    static let churCategoryGas                  = Color(hex: "F2E7D9") // amber
    static let churCategoryGroceries            = Color(hex: "E5EEDB") // sage green
    static let churCategoryStreaming            = Color(hex: "E9E2F1") // soft violet
    static let churCategoryTransit              = Color(hex: "DCE9E8") // teal
    static let churCategoryPersonalCare         = Color(hex: "F1E1EC") // blush pink
    static let churCategoryMaterialHardware     = Color(hex: "ECEBE1") // warm tan
    static let churCategoryAuto                 = Color(hex: "E1E7F0") // steel blue
    static let churCategoryGym                  = Color(hex: "FAEADF") // energetic peach
    static let churCategoryRecreation           = Color(hex: "DCF0E8") // mint
    static let churCategoryEntertainment        = Color(hex: "ECE2F4") // lavender
    static let churCategoryWholesale            = Color(hex: "F5EAD8") // warm gold
    static let churCategoryLiquorstore          = Color(hex: "F4E1E9") // rosé
    static let churCategoryProfessionalServices = Color(hex: "E4E8EF") // slate blue
    static let churCategoryDonation             = Color(hex: "F6F0DC") // warm yellow
    static let churCategoryMedicalHealth        = Color(hex: "E1F0EF") // light teal
    static let churCategoryInsurance            = Color(hex: "E2E8F3") // cool blue
    static let churCategoryUtilities            = Color(hex: "EBEBE7") // soft warm gray
    static let churCategoryTelecommunication    = Color(hex: "E1E2F3") // indigo
    static let churCategoryRetail               = Color(hex: "F0E1F0") // mauve

    /// Returns the badge tint for a parent spending category ID.
    static func categoryBadgeTint(for categoryID: String) -> Color {
        switch categoryID {
        case "dining":                return .churCategoryDining
        case "travel":                return .churCategoryTravel
        case "gas":                   return .churCategoryGas
        case "groceries":             return .churCategoryGroceries
        case "streaming":             return .churCategoryStreaming
        case "transit":               return .churCategoryTransit
        case "personal_care":         return .churCategoryPersonalCare
        case "material_hardware":     return .churCategoryMaterialHardware
        case "auto":                  return .churCategoryAuto
        case "gym":                   return .churCategoryGym
        case "recreation":            return .churCategoryRecreation
        case "entertainment":         return .churCategoryEntertainment
        case "wholesale":             return .churCategoryWholesale
        case "liquorstore":           return .churCategoryLiquorstore
        case "professional_services": return .churCategoryProfessionalServices
        case "donation":              return .churCategoryDonation
        case "medical_health":        return .churCategoryMedicalHealth
        case "insurance":             return .churCategoryInsurance
        case "utilities":             return .churCategoryUtilities
        case "telecommunication":     return .churCategoryTelecommunication
        case "retail":                return .churCategoryRetail
        default:                      return .churOliveLight
        }
    }

    // MARK: - Card Color by Issuer
    static func cardColor(for issuer: String) -> Color {
        switch issuer {
        case "Chase": return .churChase
        case "American Express": return .churAmex
        case "Citi": return .churCiti
        case "Capital One": return .churCapitalOne
        case "Bank of America": return .churBofA
        default: return .churMediumGray
        }
    }
}

// MARK: - Hex Color Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
