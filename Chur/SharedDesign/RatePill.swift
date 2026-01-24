//
//  RatePill.swift
//  Chur
//
//  Reusable capsule pill that displays an earning rate.
//  Supports points mode ("4x"), effective-rate mode ("5%"), and
//  various sizes so it can be dropped into any context.
//

import SwiftUI

struct RatePill: View {
    let text: String
    var displayMode: DisplayMode = .points
    var size: Size = .medium
    var showBackground: Bool = true
    
    // MARK: - Display Mode
    
    enum DisplayMode {
        case points              // Olive text on light olive background
        case pointsFilled        // White text on solid olive background
        case effectivePositive   // Blue text on light blue background
        case effectiveNegative   // Red text on light red background
        case programpointvalue   // black on white background
        case empty               // Gray text on light gray background
    }
    
    // MARK: - Size
    
    enum Size {
        case small    // 12pt – compact rows
        case medium   // 14pt – recommendation cards
        case large    // 18pt – category bubbles
        
        var fontSize: CGFloat {
            switch self {
            case .small:  return 12
            case .medium: return 14
            case .large:  return 18
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small:  return 6
            case .medium: return 8
            case .large:  return 10
            }
        }
        
        var verticalPadding: CGFloat {
            switch self {
            case .small:  return 2
            case .medium: return 2
            case .large:  return 4
            }
        }
    }
    
    // MARK: - Colors
    
    private var foregroundColor: Color {
        switch displayMode {
        case .points:            return Color.churOlive
        case .pointsFilled:      return .white
        case .effectivePositive: return Color.churRatebubbleBlueText
        case .effectiveNegative: return Color.churRatebubbleRedText
        case .programpointvalue: return Color.churDarkGray
        case .empty:             return Color.churDarkGray
        }
    }
    
    private var backgroundColor: Color {
        switch displayMode {
        case .points:            return Color.churOliveLight
        case .pointsFilled:      return Color.churOlive
        case .effectivePositive: return Color.churRatebubbleBlueBg.opacity(0.6)
        case .effectiveNegative: return Color.churRatebubbleRedBg.opacity(0.75)
        case .programpointvalue: return .white
        case .empty:             return Color.churLightGray
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        Text(text)
            .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, showBackground ? size.horizontalPadding : 0)
            .padding(.vertical, showBackground ? size.verticalPadding : 0)
            .background {
                if showBackground {
                    ZStack {
                        // 1. Add a solid background first
                        Capsule()
                            .fill(Color.churTiles) // or .white, depending on your theme
                        
                        // 2. Layer the tinted/transparent color on top
                        Capsule()
                            .fill(backgroundColor)
                    }
                }
            }
    }
}
// MARK: - Convenience Initializers

extension RatePill {

    /// Auto-determines display mode and text from raw rate values.
    ///
    /// - Parameters:
    ///   - rate: Points multiplier (e.g. 4.0 for "4x")
    ///   - effectiveRate: Decimal cash-back rate (e.g. 0.05 for "5%")
    ///   - showEffectiveRate: Whether user has enabled effective-rate display
    ///   - size: Pill size variant
    ///   - filledStyle: When true, points mode uses solid olive background
    init(
        rate: Double,
        effectiveRate: Double,
        showEffectiveRate: Bool,
        size: Size = .medium,
        filledStyle: Bool = false
    ) {
        self.size = size

        if showEffectiveRate {
            if effectiveRate == 0 {
                self.text = "-"
                self.displayMode = .empty
            } else {
                let pct = effectiveRate * 100
                if pct.truncatingRemainder(dividingBy: 1) == 0 {
                    self.text = "\(String(format: "%.0f", pct))%"
                } else if (pct * 10).truncatingRemainder(dividingBy: 1) == 0 {
                    self.text = "\(String(format: "%.1f", pct))%"
                } else {
                    self.text = "\(String(format: "%.2f", pct))%"
                }
                self.displayMode = effectiveRate < 0 ? .effectiveNegative : .effectivePositive
            }
        } else {
            if rate <= 0 {
                self.text = "-"
                self.displayMode = .empty
            } else {
                if rate == floor(rate) {
                    self.text = "\(Int(rate))x"
                } else if (rate * 10).truncatingRemainder(dividingBy: 1) == 0 {
                    self.text = String(format: "%.1fx", rate)
                } else {
                    self.text = String(format: "%.2fx", rate)
                }
                self.displayMode = filledStyle ? .pointsFilled : .points
            }
        }
    }
}
