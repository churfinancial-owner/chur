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
    
    // MARK: - Card Issuers
    static let churChase = Color(hex: "1A4F8B")
    static let churAmex = Color(hex: "006FCF")
    static let churCiti = Color(hex: "003D6A")
    static let churCapitalOne = Color(hex: "DB3D2C")
    static let churBofA = Color(hex: "E31837")
    
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
