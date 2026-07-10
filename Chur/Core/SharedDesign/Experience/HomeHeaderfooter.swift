//
//  HomeHeaderfooter.swift
//  Chur
//
//  Home screen header components:
//  - CurvedHeaderView: Gradient header with time-based greeting and location
//  - CurvedBottomShape: Custom shape for curved header bottom
//
//  Created by Pak Ho on 1/22/26.
//

import SwiftUI

private enum HomeHeaderStyle {
    static let height: CGFloat = 160

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 186/255, green: 184/255, blue: 108/255), // Olive green #BAB86C
                Color(red: 0.96, green: 0.94, blue: 0.86)            // Beige
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum HeaderWaveStyle {
    case home
    case cards
    case user
    case search
}

// MARK: - Curved Header Background Component
struct CurvedHeaderBackgroundView: View {
    var waveStyle: HeaderWaveStyle = .home

    var body: some View {
        HomeHeaderStyle.backgroundGradient
            .frame(height: HomeHeaderStyle.height)
            .clipShape(CurvedBottomShape(waveStyle: waveStyle))
            .frame(height: HomeHeaderStyle.height)
    }
}

// MARK: - Curved Header View Component
struct CurvedHeaderView: View {
    let userName: String
    let currentDate: String
    var waveStyle: HeaderWaveStyle = .home
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                CurvedHeaderBackgroundView(waveStyle: waveStyle)
                
                // Header text content (left-aligned)
                VStack(alignment: .leading, spacing: 6) {
                    // Greeting with emoji after name
                    Text(greeting + " \(greetingEmoji)")
                        .font(.churTitle2())
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    
                    // Date
                    Text(currentDate)
                        .font(.churCaptionMedium())
                        .foregroundColor(.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .padding(.top, geometry.safeAreaInsets.top + 70)
                .padding(.horizontal, 10)
            }
        }
        .frame(height: HomeHeaderStyle.height)
    }
    
    // Greeting based on time of day
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date.current())
        switch hour {
        case 0..<12:
            return "Good Morning~"
        case 12..<17:
            return "Good Afternoon"
        case 17..<22:
            return "Good Evening"
        default:
            return "Good Night!"
        }
    }
    
    // Emoji based on time of day (after name)
    private var greetingEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date.current())
        switch hour {
        case 6..<12:
            return "☀️"
        case 12..<18:
            return "👋"
        case 18..<22:
            return "🌙"
        default:
            return "😴"
        }
    }
}

// MARK: - Curved Bottom Shape
struct CurvedBottomShape: Shape {
    var waveStyle: HeaderWaveStyle = .home

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseline = rect.height - 34

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: baseline))

        let wave = waveSpec

        // Double-wave bottom edge: two flowing curves with alternating peaks/troughs.
        path.addCurve(
            to: CGPoint(x: rect.width * 0.5, y: baseline + wave.midY),
            control1: CGPoint(x: rect.width * wave.firstC1X, y: baseline + wave.firstC1Y),
            control2: CGPoint(x: rect.width * wave.firstC2X, y: baseline + wave.firstC2Y)
        )
        path.addCurve(
            to: CGPoint(x: rect.width, y: baseline + wave.endY),
            control1: CGPoint(x: rect.width * wave.secondC1X, y: baseline + wave.secondC1Y),
            control2: CGPoint(x: rect.width * wave.secondC2X, y: baseline + wave.secondC2Y)
        )

        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.closeSubpath()
        return path
    }

    private var waveSpec: (
        midY: CGFloat,
        endY: CGFloat,
        firstC1X: CGFloat, firstC1Y: CGFloat,
        firstC2X: CGFloat, firstC2Y: CGFloat,
        secondC1X: CGFloat, secondC1Y: CGFloat,
        secondC2X: CGFloat, secondC2Y: CGFloat
    ) {
        switch waveStyle {
        case .home:
            return (
                midY: 0, endY: 0,
                firstC1X: 0.20, firstC1Y: 25,
                firstC2X: 0.40, firstC2Y: -25,
                secondC1X: 0.60, secondC1Y: 25,
                secondC2X: 0.80, secondC2Y: -25
            )
        case .cards:
            return (
                midY: 10, endY: -5,
                firstC1X: 0.15, firstC1Y: 45,   // Pushed way up
                firstC2X: 0.35, firstC2Y: -40,  // Pulled way down
                secondC1X: 0.65, secondC1Y: 40,
                secondC2X: 0.85, secondC2Y: -45
            )
        case .user:
            return (
                midY: -8, endY: 8,
                firstC1X: 0.10, firstC1Y: 15,   // Subtle start
                firstC2X: 0.30, firstC2Y: -10,
                secondC1X: 0.75, secondC1Y: 50, // Massive swoop near the end
                secondC2X: 0.90, secondC2Y: -20
            )
        case .search:
            return (
                midY: 3, endY: 2,
                firstC1X: 0.25, firstC1Y: -30,  // Notice the negative! Starts by dipping down.
                firstC2X: 0.45, firstC2Y: 30,
                secondC1X: 0.55, secondC1Y: -25,
                secondC2X: 0.75, secondC2Y: 25            )
        }
    }
}

// Create a global constant for easier maintenance
struct UIConstants {
    static let tabBarHeight: CGFloat = 80
}

