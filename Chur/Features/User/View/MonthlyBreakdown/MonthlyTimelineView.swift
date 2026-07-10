//
//  MonthlyTimelineView.swift
//  Chur
//
//  Created by Pak Ho on 2/2/26.
//

import SwiftUI
import SwiftData

struct MonthlyTimelineView: View {
    let cards: [CreditCard]
    let feesForMonth: (Int, Int) -> Int
    let savingsForMonth: (Int, Int) -> Int
    @Binding var selectedMonth: Int?
    @Binding var selectedYear: Int
    
    @State private var showInfoTip = false
    
    private let numericMonths = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]
    private let chartAreaHeight: CGFloat = 160 // Taller for better visual resolution

    var maxFees: CGFloat {
        let values = (1...12).map { CGFloat(feesForMonth($0, selectedYear)) }
        return (values.max() ?? 100) * 1.2
    }

    var maxSavings: CGFloat {
        let values = (1...12).map { CGFloat(savingsForMonth($0, selectedYear)) }
        return (values.max() ?? 100) * 1.2
    }

    private var currentMonth: Int { Calendar.current.component(.month, from: Date.now) }
    private var currentYear: Int { Calendar.current.component(.year, from: Date.now) }
    
    var body: some View {
        VStack(spacing: 20) {
            // MARK: - Header
            HStack(spacing: 8) {
                Text("MONTHLY BREAKDOWN")
                    .font(.churMicroBold())
                    .foregroundStyle(Color.churMediumGray)
                    .tracking(1.2)
                
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showInfoTip.toggle()
                    }
                } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.churCaptionRegular())
                        .foregroundStyle(Color.churLightGray.opacity(0.6))
                }
                
                Spacer()
                
            }
            .padding(.horizontal, 24)
            
            // MARK: - Timeline Scroll
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 18) {
                        ForEach(1...12, id: \.self) { monthNumber in
                            let ytdNet = (1...monthNumber).reduce(0) { total, m in
                                total + savingsForMonth(m, selectedYear) - feesForMonth(m, selectedYear)
                            }
                            
                            MonthBarView(
                                monthLabel: numericMonths[monthNumber - 1],
                                monthNumber: monthNumber,
                                fees: feesForMonth(monthNumber, selectedYear),
                                savings: savingsForMonth(monthNumber, selectedYear),
                                maxFees: maxFees,
                                maxSavings: maxSavings,
                                chartAreaHeight: chartAreaHeight,
                                isCurrentMonth: selectedYear == currentYear && monthNumber == currentMonth,
                                cumulativeNetToDate: ytdNet,
                                onSelect: {
                                    selectedMonth = monthNumber
                                }
                            )
                            .id(monthNumber)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
                .onAppear {
                    if selectedYear == currentYear {
                        proxy.scrollTo(currentMonth, anchor: .center)
                    }
                }
                .onChange(of: selectedYear) {
                    if selectedYear == currentYear {
                        withAnimation { proxy.scrollTo(currentMonth, anchor: .center) }
                    } else {
                        withAnimation { proxy.scrollTo(1, anchor: .leading) }
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if showInfoTip {
                infoTooltip
                    .padding(.top, 40)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }

    private func calculateYTDNet() -> Int {
        (1...12).reduce(0) { $0 + savingsForMonth($1, selectedYear) - feesForMonth($1, selectedYear) }
    }

    private var infoTooltip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Redeemed", systemImage: "arrow.up").foregroundStyle(.green)
            Label("Annual Fees", systemImage: "arrow.down").foregroundStyle(.red)
        }
        .font(.churMicroBold())
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .onTapGesture {
            withAnimation { showInfoTip = false }
        }
    }
}
