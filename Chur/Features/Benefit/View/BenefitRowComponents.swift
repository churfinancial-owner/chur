//
//  BenefitRowComponents.swift
//  Chur
//
//  Created by Pak Ho on 3/10/26.
//
//  Description: Stateless, reusable UI atoms like ChurStatusPill and
//               BenefitCheckboxButton to maintain design consistency.

import SwiftUI

struct BenefitCheckboxButton: View {
    let isLocked: Bool
    let needsActivation: Bool
    let isUsed: Bool
    var isUnlimited: Bool = false
    var isCountLimited: Bool = false
    var isFullyRedeemed: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            if isLocked {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.churLightGray)
            } else if isUnlimited {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.churOlive)
            } else if isCountLimited {
                Image(systemName: isFullyRedeemed ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.churOlive)
            } else {
                Image(systemName: isUsed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(isUsed ? Color.churOlive : Color.churLightGray)
            }
        }
        .buttonStyle(.plain)
    }
}

/// A unified capsule-shaped status indicator used throughout the app.
///
/// Two visual styles:
/// - `.filled`: white text on an opaque colored background (row-level frequency labels).
///   Pass `isUsed: true` to dim the background opacity, signalling the benefit is spent.
/// - `.tinted`: colored text/icon on a lightly-tinted background (detail sheet header pills).
///
/// Set `compact: true` for the smaller row-level variant (size 9 / padding 8×5);
/// the default size is suitable for header pills (size 10 / padding 12×6).
struct ChurStatusPill: View {
    
    enum Style {
        case filled(isUsed: Bool = false)
        case tinted
    }
    
    let label: String
    let color: Color
    var icon: String? = nil
    var style: Style = .filled()
    var compact: Bool = false
    var isCollapsed: Bool = false
    
    
    /// Canonical frequency → color mapping. Pass a custom `default` when an
    /// unknown frequency should fall back to something other than churOlive.
    static func color(for frequency: String, default defaultColor: Color = Color.churOlive) -> Color {
        switch frequency.lowercased() {
        case "monthly":     return .orange
        case "quarterly":   return .yellow
        case "semi-annual": return .green
        case "annual":      return .blue
        case "quadrennial": return .cyan
        case "one-time":    return .red
        case "ongoing":     return .purple
        default:            return defaultColor
        }
    }
    
    private var fontSize: CGFloat { compact ? 9 : 10 }
    private var hPad: CGFloat    { compact ? 8 : 12 }
    private var vPad: CGFloat    { compact ? 5 : 6 }
    
    private var labelColor: Color {
        switch style {
        case .filled:  return .white
        case .tinted:  return color
        }
    }
    
    private var bgColor: Color {
        switch style {
        case .filled(let isUsed): return color.opacity(isUsed ? 0.3 : 0.9)
        case .tinted:             return color.opacity(0.08)
        }
    }
    
    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .foregroundStyle(labelColor)
            }
            
            // Logic to show prefix only when collapsed
            Text(isCollapsed ? String(label.prefix(1)) : label)
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundStyle(labelColor)
        }
        .padding(.horizontal, isCollapsed ? vPad : hPad) // Make it circular when collapsed
        .padding(.vertical, vPad)
        .background(bgColor)
        .clipShape(isCollapsed ? AnyShape(Circle()) : AnyShape(Capsule())) // Circle vs Capsule
    }
}
