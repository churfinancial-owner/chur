
//
//  OnboardingWelcomeStep.swift
//  Chur
//
//  V3.3: Cute, centered, hero layout with massive Chur header.
//

import SwiftUI

struct OnboardingWelcomeStep: View {
    let onContinue: () -> Void

    @State private var activeCard = 0
    @State private var creditRedeemed = false

    private typealias CardData = (color: Color, issuer: String, name: String, rate: String, category: String, credit: String)
    private let cards: [CardData] = [
        (.churChase, "My Bank", "Diamond", "3x", "Dining", "$300 Travel Credits"),
        (.churAmex,  "Piggy Bank",    "Card #26",    "4x", "Groceries", "$15 Streaming Credits"),
        (.churGold,  "CHUR",    "Best card", "5x", "This location", "$100 Dining Credits"),
    ]

    var body: some View {
        ZStack {
            Color.churOffWhite.ignoresSafeArea()
            
            WorldMapBackground()
                .ignoresSafeArea()
                .opacity(0.1) // Slightly increased visibility

            RadialDotGridBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                
                // Flexible spacer to push main hero down
                Spacer()
                    .frame(height: 50)

                // --- Massive "Chur" Header (NEW) ---
                Text("Chur")
                    .font(.churBigTitle())
                    .foregroundStyle(Color.churOlive)
                    .tracking(-1.5)
                    .padding(.bottom, -15)
                
                // --- Animated Card Stack ---
                ZStack {
                    ForEach(0..<cards.count, id: \.self) { i in
                        let stackOffset = (i - activeCard + cards.count) % cards.count
                        WelcomeCardView(
                            color: cards[i].color,
                            issuer: cards[i].issuer,
                            name: cards[i].name,
                            rate: cards[i].rate,
                            category: cards[i].category,
                            credit: cards[i].credit,
                            stackOffset: stackOffset,
                            isCreditRedeemed: $creditRedeemed
                        )
                    }
                }
                .frame(width: 260, height: 260) // Refined frame size
                .padding(.top, 10)

                // --- Text Content & Features ---
                VStack(spacing: 20) {

                    (Text("Your Wallet. ")
                        .foregroundStyle(Color.churMediumGray) +
                     Text("Smarter.")
                        .foregroundStyle(Color.churOlive))
                        .font(.churBigTitle4())
                        .tracking(0.5)
                        .padding(.top, 10)
                    
                    // --- Neatly Listed Features (Cute, Centered Cards) ---
                    VStack(alignment: .center, spacing: 10) {
                        FeatureRowOnboarding(icon: "📍", text: "Suggest the best card for every purchase")
                        FeatureRowOnboarding(icon: "🎁", text: "Track and maximize your card benefits")
                        FeatureRowOnboarding(icon: "🔧", text: "Access quick tools to boost perks")
                    }
                    .padding(.horizontal, 28)
                }
                .padding(.top, 15)
                
                Spacer()

                // --- CTA Button ---
                Button(action: onContinue) {
                    Text("Let's go →")
                        .font(.churHeadline())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.churOlive) // Match header
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.churOlive.opacity(0.25), radius: 10, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 30)
                .padding(.bottom, 25)
            }
        }
        .task {
            while !Task.isCancelled {
                // 1. Wait while the card is sitting still
                try? await Task.sleep(for: .seconds(0.4))
                
                // 2. Show the stamp (it stays visible now)
                withAnimation { creditRedeemed = true }
                
                // 3. Wait for the remainder of the card's display time
                try? await Task.sleep(for: .seconds(2.1))
                
                // 4. Reset the stamp SILENTLY (no animation) right before the flip
                // so it doesn't "fade out" while the card is moving
                creditRedeemed = false
                
                // 5. Flip to the next card
                withAnimation(.timingCurve(0.3, 0.9, 0.3, 1.0, duration: 0.8)) {
                    activeCard = (activeCard + 1) % cards.count
                }
            }
        }
    }
}

// MARK: - Feature Row Component (Cute styling)

private struct FeatureRowOnboarding: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.churBody())
                .frame(width: 28, height: 28)
                .background(.white)
                .clipShape(Circle())

            Text(text)
                .font(.churCaptionMedium())
                .foregroundStyle(Color.churDarkGray)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.churGoldGradient.opacity(0.4)) // Softer, tinted card background
        .clipShape(Capsule())
    }
}

// MARK: - (Reuse Previous Card Logic)
// Note: Keep your WelcomeCardView, WelcomeCardMockView, RewardBadgeView,
// WorldMapBackground, DotGridBackground, ScaleButtonStyle, and Color Darkening
// helpers from the previous step here to complete the file.
// MARK: - Card Stack Item

private struct WelcomeCardView: View {
    let color: Color
    let issuer: String
    let name: String
    let rate: String
    let category: String
    let credit: String
    let stackOffset: Int
    @Binding var isCreditRedeemed: Bool // Bind to the parent state

    var body: some View {
        let yOffset   = CGFloat(stackOffset) * 12
        let scale     = 1.0 - Double(stackOffset) * 0.06
        let rotation  = Double(stackOffset - 1) * 3.0
        let opacity   = 1.0 - Double(stackOffset) * 0.15

        WelcomeCardMockView(color: color, issuer: issuer, name: name, credit: credit, isCreditRedeemed: $isCreditRedeemed, stackOffset: stackOffset)
            .overlay(alignment: .topTrailing) {
                if stackOffset == 0 {
                    RewardBadgeView(rate: rate, category: category)
                        .offset(x: 10, y: -14)
                }
            }
            .offset(y: yOffset)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .zIndex(Double(10 - stackOffset))
    }
}

// MARK: - Credit Card Mock

private struct WelcomeCardMockView: View {
    let color: Color
    let issuer: String
    let name: String
    let credit: String
    @Binding var isCreditRedeemed: Bool
    let stackOffset: Int

    private let width: CGFloat = 240

    var body: some View {
        let height       = width * 0.63
        let cornerRadius = width * 0.06

        ZStack(alignment: .topLeading) {
            // Gradient background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(LinearGradient(
                    colors: [color, color.darkened(by: 0.18)],
                    startPoint: UnitPoint(x: 0.13, y: 0.13),
                    endPoint: UnitPoint(x: 0.87, y: 0.87)
                ))
                .shadow(color: .black.opacity(0.22), radius: 15, x: 0, y: 14)
                .shadow(color: .black.opacity(0.10), radius: 6,  x: 0, y: 2)

            // Shine overlay
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.12), location: 0),
                        .init(color: .clear,               location: 0.4),
                        .init(color: .clear,               location: 0.6),
                        .init(color: .white.opacity(0.06), location: 1),
                    ],
                    startPoint: UnitPoint(x: 0.08, y: 0.12),
                    endPoint:   UnitPoint(x: 0.92, y: 0.88)
                ))

            // Decorative arc pattern (top-right)
            Canvas { context, size in
                let cx = size.width * 0.86
                let cy = size.height * 0.17
                for radius in [CGFloat(90), 60, 30] {
                    let path = Path(ellipseIn: CGRect(
                        x: cx - radius, y: cy - radius,
                        width: radius * 2, height: radius * 2
                    ))
                    context.stroke(path, with: .color(.white), lineWidth: 1)
                }
            }
            .opacity(0.14)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            // Card content
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    Text(issuer)
                        .font(.system(size: width * 0.045, weight: .heavy))
                        .foregroundStyle(.white)
                        .tracking(1.5)
                    Spacer()
                    // EMV chip
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "D4B483"))
                        .frame(width: width * 0.11, height: width * 0.085)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                        )
                }
                Spacer()
                
                // Name and Travel Credit section
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: width * 0.05, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    // New Travel Credit Call-out with stamp animation
                    Text(credit)
                        .font(.system(size: width * 0.035, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isCreditRedeemed && stackOffset == 0 ? .white.opacity(0.15) : .clear) // Highlight pulse
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            // Stamp: "REDEEMED" with cute styling
                            Text("REDEEMED ✅")
                                .font(.system(size: width * 0.028, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.churChase) // Use a contrasting brand color
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .rotationEffect(.degrees(-10)) // Cute diagonal angle
                                .opacity(isCreditRedeemed && stackOffset == 0 ? 1 : 0)
                                .scaleEffect(isCreditRedeemed && stackOffset == 0 ? 1 : 1.3)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0), value: isCreditRedeemed),
                            alignment: .center
                        )
                        .animation(.easeInOut(duration: 0.3), value: isCreditRedeemed)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(width * 0.06)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Reward Badge

private struct RewardBadgeView: View {
    let rate: String
    let category: String

    @State private var pulse = false

    var body: some View {
        Text("\(rate) \(category) ✨")
            .font(.churSmallBold())
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Color.churOlive)
            .clipShape(Capsule())
            .shadow(color: Color.churOlive.opacity(0.35), radius: 18, x: 0, y: 6)
            .scaleEffect(pulse ? 1.05 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

// MARK: - World Map Background

private struct WorldMapBackground: View {
    var body: some View {
        // ASSUMPTION: You have an image asset named "churMapAsset" that is a
        // light-colored outline of a world map, suitable for tiling.
        Image("churMapAsset")
            .resizable(resizingMode: .tile)
            .font(.title) // Make icons larger if using symbols
            .foregroundStyle(Color.churOlive)
    }
}

// MARK: - Radial Dot Grid Background (Welcome-specific, fades toward edges)

private struct RadialDotGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing:   CGFloat = 24
            let dotRadius: CGFloat = 1
            let cols = Int(size.width  / spacing) + 2
            let rows = Int(size.height / spacing) + 2
            let cx = size.width  / 2
            let cy = size.height / 2
            let maxDist = (cx * cx + cy * cy).squareRoot()

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing
                    let dist = ((x - cx) * (x - cx) + (y - cy) * (y - cy)).squareRoot()
                    let t     = (dist / maxDist - 0.4) / 0.4
                    let alpha = max(0, min(1, 1 - t))
                    guard alpha > 0.01 else { continue }

                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius,
                                     width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(Color.churOlive.opacity(0.08 * alpha)))
                }
            }
        }
    }
}

// MARK: - Color darkening helper

private extension Color {
    func darkened(by fraction: CGFloat) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red:     Double(max(0, r * (1 - fraction))),
            green:   Double(max(0, g * (1 - fraction))),
            blue:    Double(max(0, b * (1 - fraction))),
            opacity: Double(a)
        )
    }
}

