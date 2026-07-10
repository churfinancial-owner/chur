//
//  BadgeIcon.swift
//  ChurApp
//
//  Description: 787-style window with Indigo electronic tinting.
//

import SwiftUI

struct BadgeIcon: View {
    let badge: Badge
    let unlocked: Bool
    let tier: BadgeTier
    
    private let windowWidth: CGFloat = 85
    private let windowHeight: CGFloat = 110
    private let bezelWidth: CGFloat = 3

    // Indigo Dimmer — animated from fully dimmed to tier target
    @State private var tintOpacity: Double = 0.90

    private var targetTintOpacity: Double {
        if !unlocked { return 0.90 }
        switch tier {
        case .tier1: return 0.60
        case .tier2: return 0.30
        case .tier3: return 0.00
        default: return 0.90
        }
    }

    var body: some View {
        ZStack {
            // 1. THE VIEW OUTSIDE (The Badge Content)
            content
                .clipShape(Capsule())
            
            // 2. THE INDIGO ELECTRONIC TINT
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.05, blue: 0.3), // Deep Indigo
                            Color(red: 0.05, green: 0, blue: 0.15)    // Near Black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(tintOpacity)
                .overlay(
                    Capsule()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 0.5) // Subtle "Electric" edge
                )
            
            // 3. THE WINDOW BEZEL (Inner Rim)
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.7), .gray.opacity(0.4), .black.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: bezelWidth
                )
            
            // 4. GLASS REFLECTION / SUN STREAK
            if tier == .tier3 && unlocked {
                sunGlint
            } else {
                glassReflection
            }
        }
        .frame(width: windowWidth, height: windowHeight)
        // 5. THE CABIN WALL (Outer Depth)
        .background(
            Capsule()
                .stroke(Color.churLightGray.opacity(0.5), lineWidth: 8)
                .blur(radius: 2)
        )
        .padding(6)
        .onAppear {
            // Reset to fully dimmed
            tintOpacity = 0.90
            // Stage 1: Tint fully clears
            withAnimation(.easeOut(duration: 1.8).delay(2)) {
                tintOpacity = targetTintOpacity
            }
        }
        .onDisappear {
            // Reset so the animation replays on next scroll-in
            tintOpacity = 0.90
        }
    }

    private var sunGlint: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.4), .clear, .white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .rotationEffect(.degrees(-10))
            .scaleEffect(1.2)
            .mask(Capsule())
    }

    private var glassReflection: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.1), .clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            )
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            Color.churOlive.opacity(0.8) // Base color for symbols/emojis
            
            if let icon = badge.icon, UIImage(named: icon) != nil {
                Image(icon)
                    .resizable()
                    .scaledToFill()
                    .frame(width: windowWidth, height: windowHeight)
            } else if let icon = badge.icon {
                Image(systemName: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(22)
                    .foregroundStyle(.white)
            } else {
                Text(badge.emoji)
                    .font(.churCounter())
            }
        }
    }
}
