//
//  MonthBarView.swift
//  Chur
//
//  Created by Pak Ho on 2/2/26.
//  Proportional vertical bar stack using ZStack/VStack for multi-metric visualization.
//  Includes Tap/LongPress redundancy and UIImpactFeedback for enhanced tactile response.
//



import SwiftUI

struct MonthBarView: View {
    let monthLabel: String
    let monthNumber: Int
    let fees: Int
    let savings: Int
    let maxValue: CGFloat
    let chartAreaHeight: CGFloat
    let isCurrentMonth: Bool
    let cumulativeNetToDate: Int // You can keep this for logic, or remove if no longer needed
    let onSelect: () -> Void
    
    let barWidth: CGFloat = 28
    let cornerRadius: CGFloat = 14
    
    private func barHeight(for value: Int) -> CGFloat {
        guard maxValue > 0, value > 0 else { return 0 }
        let calculated = (CGFloat(value) / maxValue) * (chartAreaHeight / 2)
        return max(calculated, 6)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Updated ZStack without the chameleon dot
            ZStack {
                // Background Track
                Capsule()
                    .fill(Color.primary.opacity(0.02))
                    .frame(width: barWidth, height: chartAreaHeight)
                
                // Earnings (Up)
                VStack(spacing: 0) {
                    Spacer()
                    UnevenRoundedRectangle(topLeadingRadius: cornerRadius, topTrailingRadius: cornerRadius)
                        .fill(LinearGradient(
                            colors: [.green.opacity(0.7), .green.opacity(0.2)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: barWidth, height: barHeight(for: savings))
                    Rectangle().fill(.clear).frame(height: chartAreaHeight / 2)
                }

                // Fees (Down)
                VStack(spacing: 0) {
                    Rectangle().fill(.clear).frame(height: chartAreaHeight / 2)
                    UnevenRoundedRectangle(bottomLeadingRadius: cornerRadius, bottomTrailingRadius: cornerRadius)
                        .fill(LinearGradient(
                            colors: [.red.opacity(0.1), .red.opacity(0.5)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: barWidth, height: barHeight(for: fees))
                    Spacer()
                }
            }
            .frame(height: chartAreaHeight)
            
            Text(monthLabel)
                .font(.churMicroBold())
                .foregroundStyle(isCurrentMonth ? Color.churOlive : .secondary)
                .overlay(alignment: .bottom) {
                    if isCurrentMonth {
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.churBadge())
                            .foregroundStyle(Color.churOlive)
                            .offset(y: 10)
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
