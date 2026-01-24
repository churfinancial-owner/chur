//
//  CustomPageIndicator.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import SwiftUI

struct CustomPageIndicator: View {
    let currentPage: Int
    let totalCards: Int
    
    private let maxVisibleDots = 5
    
    var body: some View {
        HStack(spacing: 6) {
            // Updated: Start from 0 and go up to totalCards - 1
            ForEach(0..<totalCards, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.churOlive : Color.churOlive.opacity(0.3))
                    .frame(width: dotSize(for: index), height: dotSize(for: index))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
            }
        }
        .frame(width: CGFloat(maxVisibleDots * 14))
        .clipped()
    }
    
    private func dotSize(for index: Int) -> CGFloat {
        let distance = abs(index - currentPage)
        
        if distance == 0 {
            return 8
        } else if distance == 1 {
            return 6
        } else if distance == 2 {
            return 4
        } else {
            return 0
        }
    }
}
