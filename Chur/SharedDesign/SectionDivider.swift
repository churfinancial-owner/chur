//
//  SectionDivider.swift
//  Chur
//
//  Created by Pak Ho on 1/25/26.
//

import SwiftUI
import SwiftData

// MARK: - Section Divider
struct SectionDivider: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.churSmallBold())
                .foregroundStyle(Color.churMediumGray)
                .tracking(1.0)

            Rectangle()
                .fill(Color.churLightGray.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.top, 8)
    }
}

// MARK: - Wave Divider Shape
struct WaveDivider: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Start at left-middle
        path.move(to: CGPoint(x: 0, y: height * 0.7))
        
        // A smooth Bezier curve to create the "wave" look
        path.addCurve(
            to: CGPoint(x: width, y: height * 0.2),
            control1: CGPoint(x: width * 0.35, y: 0),
            control2: CGPoint(x: width * 0.85, y: height)
        )
        
        return path
    }
}



