/*
//
//  HomeHeader_Title.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import SwiftUI

struct UnifiedHeaderModifier: ViewModifier {
    let title: String
    let safeArea: CGFloat
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content // This is your ScrollView/Content
            
            // The Title Overlay - Defined ONCE for the whole app
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.churHero())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .padding(.top, safeArea + 70)
                    .padding(.horizontal, 10) // Standardized gutter
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 160)
            .allowsHitTesting(false) // Let taps pass through to the scrollview
        }
    }
}
*/
