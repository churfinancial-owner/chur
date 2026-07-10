//
//  MonthBarView.swift
//  Chur
//
//  Created by Pak Ho on 2/2/26.
//

import SwiftUI

struct MonthBarView: View {
    let monthLabel: String
    let monthNumber: Int
    let fees: Int
    let savings: Int
    let maxFees: CGFloat
    let maxSavings: CGFloat
    let chartAreaHeight: CGFloat
    let isCurrentMonth: Bool
    let cumulativeNetToDate: Int
    let onSelect: () -> Void
    
    let barWidth: CGFloat = 30
    let cornerRadius: CGFloat = 12
    
    private func savingsHeight() -> CGFloat {
        guard maxSavings > 0, savings > 0 else { return 0 }
        return max((CGFloat(savings) / maxSavings) * (chartAreaHeight / 2), 6)
    }

    private func feesHeight() -> CGFloat {
        guard maxFees > 0, fees > 0 else { return 0 }
        return max((CGFloat(fees) / maxFees) * (chartAreaHeight / 2), 6)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // 1. Background Track
                Capsule()
                    .fill(Color.primary.opacity(0.03))
                    .frame(width: barWidth, height: chartAreaHeight)
                
                // 2. Zero-Baseline
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: barWidth + 4, height: 1.5)

                // 3. Earnings (Top Stack)
                VStack(spacing: 0) {
                    Spacer()
                    ZStack(alignment: .top) {
                        UnevenRoundedRectangle(topLeadingRadius: cornerRadius, topTrailingRadius: cornerRadius)
                            .fill(LinearGradient(
                                colors: [.green.opacity(0.7), .green.opacity(0.2)],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .frame(width: barWidth, height: savingsHeight())
                        
                        // Lollipop Marker
                        if savings > 0 {
                            Circle()
                                .fill(.green.opacity(0.8))
                                .frame(width: 4, height: 4)
                                .padding(.top, 4)
                        }
                    }
                    Rectangle().fill(.clear).frame(height: chartAreaHeight / 2)
                }

                // 4. Fees (Bottom Stack)
                VStack(spacing: 0) {
                    Rectangle().fill(.clear).frame(height: chartAreaHeight / 2)
                    ZStack(alignment: .bottom) {
                        UnevenRoundedRectangle(bottomLeadingRadius: cornerRadius, bottomTrailingRadius: cornerRadius)
                            .fill(LinearGradient(
                                colors: [.red.opacity(0.1), .red.opacity(0.6)],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .frame(width: barWidth, height: feesHeight())
                        
                        // Lollipop Marker
                        if fees > 0 {
                            Circle()
                                .fill(.red.opacity(0.8))
                                .frame(width: 4, height: 4)
                                .padding(.bottom, 4)
                        }
                    }
                    Spacer()
                }
            }
            .frame(height: chartAreaHeight)
            
            // 5. Month Label & Current Indicator
            Text(monthLabel)
                .font(.churBadgeBold())
                .foregroundStyle(isCurrentMonth ? Color.churOlive : Color.secondary.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isCurrentMonth ? Color.churOlive.opacity(0.1) : Color.clear)
                .clipShape(Capsule())
                .overlay(alignment: .bottom) {
                    if isCurrentMonth {
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.churOlive)
                            .offset(y: 14)
                    }
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            onSelect()
        }
    }
}
