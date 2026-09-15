//
//  RatePill.swift
//  Chur
//
//  Reusable capsule pill that displays an earning rate.
//  Enhanced with soft-depth gradients and "Chur" design system typography.
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
        case programpointvalue   // Black on white background
        case empty               // Gray text on light gray background
    }

    // MARK: - Size
    enum Size {
        case small
        case medium
        case large
        case hero

        var font: Font {
            switch self {
            case .small:  return .churSmall()
            case .medium: return .churSubheadline()
            case .large:  return .churHeadline()
            case .hero:   return .churTitle2()
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small:  return 6
            case .medium: return 8
            case .large:  return 10
            case .hero:   return 0
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small:  return 3
            case .medium: return 4
            case .large:  return 5
            case .hero:   return 0
            }
        }

        var fixedWidth: CGFloat? {
            switch self {
            case .small:  return 54
            case .medium: return 64
            case .large:  return 80
            case .hero:   return nil
            }
        }
    }

    // MARK: - Dynamic Colors
    private var foregroundColor: Color {
        switch displayMode {
        case .points:            return Color.churOlivetext  // Updated to your brand text color
        case .pointsFilled:      return .white
        case .effectivePositive: return Color.churInfo       // Using brand accent
        case .effectiveNegative: return Color.churError      // Using brand accent
        case .programpointvalue: return Color.churDarkGray
        case .empty:             return Color.churDarkGray
        }
    }

    private var backgroundColor: Color {
        switch displayMode {
        case .points:            return Color.churOliveLight2.opacity(0.4)
        case .pointsFilled:      return Color.churOliveDark
        case .effectivePositive: return Color.churInfo.opacity(0.15)
        case .effectiveNegative: return Color.churError.opacity(0.15)
        case .programpointvalue: return .white
        case .empty:             return Color.churLightGray.opacity(0.5)
        }
    }

    /// With a background the pill is tight, so a decimal rounds to a whole number:
    /// `1.5x` reads `2x`. Only above 1, though — rounding a rate that is already
    /// below 1 destroys it rather than shortening it, and MMPower's 0.4% base read
    /// as `0%`. Per-mile strings end in neither suffix and pass through untouched.
    private var displayText: String {
        guard showBackground else { return text }
        if text.hasSuffix("x"), let value = Double(text.dropLast()), abs(value) >= 1 {
            return "\(Int(value.rounded()))x"
        }
        if text.hasSuffix("%"), let value = Double(text.dropLast()), abs(value) >= 1 {
            return "\(Int(value.rounded()))%"
        }
        return text
    }

    // MARK: - Body
    var body: some View {
        Text(displayText)
            .font(size.font)
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, showBackground ? size.horizontalPadding : 0)
            .padding(.vertical, showBackground ? size.verticalPadding : 0)
            .frame(width: showBackground ? nil : size.fixedWidth, alignment: .center)
            .background {
                if showBackground {
                    Capsule()
                        .fill(backgroundColor.gradient) // Adds professional shimmer
                        .shadow(color: backgroundColor.opacity(0.3), radius: 3, x: 0, y: 1)
                }
            }
            .overlay {
                if showBackground {
                    Capsule()
                        .strokeBorder(foregroundColor.opacity(0.12), lineWidth: 1) // "Glass" edge
                }
            }
    }
}

// MARK: - Convenience Initializers
extension RatePill {
    /// Builds the pill from the numbers rather than a string.
    ///
    /// `program` is what lets the rate read the way its own program quotes it.
    /// This initializer used to format both numbers itself — a ninth formatter,
    /// living in the design system where nobody looked for one — and having no
    /// program it printed Asia Miles' 0.25 miles per dollar as "0.2x" on the
    /// Earning Power screen while every other screen said "HK$4/mile". It also
    /// rounded the effective rate to one decimal where the rest of the app uses
    /// two. Both numbers now come from `RateDisplay`, which is the only thing
    /// that decides how a rate reads.
    init(
        rate: Double,
        effectiveRate: Double,
        showEffectiveRate: Bool,
        program: String?,
        size: Size = .medium,
        filledStyle: Bool = false,
        showBackground: Bool = true
    ) {
        self.size = size
        self.showBackground = showBackground
        self.text = RateDisplay.preferred(
            rate: rate,
            effectiveRate: effectiveRate,
            program: program,
            showEffectiveRate: showEffectiveRate
        )
        let mode = RateDisplay.pillMode(rate: rate, effectiveRate: effectiveRate, showEffectiveRate: showEffectiveRate)
        self.displayMode = (filledStyle && mode == .points) ? .pointsFilled : mode
    }
}
