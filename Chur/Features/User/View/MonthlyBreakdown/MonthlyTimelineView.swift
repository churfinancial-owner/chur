//
//  MonthBarView.swift
//  Chur
//
//  Created by Pak Ho on 2/2/26.
//  Proportional vertical bar stack using ZStack/VStack for multi-metric visualization.
//  Includes Tap/LongPress redundancy and UIImpactFeedback for enhanced tactile response.
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
    private let chartAreaHeight: CGFloat = 140

    var maxValue: CGFloat {
        let allValues = (1...12).flatMap { m in
            [CGFloat(feesForMonth(m, selectedYear)), CGFloat(savingsForMonth(m, selectedYear))]
        }
        return (allValues.max() ?? 100) * 1.2
    }

    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date.current())
    }
    
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date.current())
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 12) {
                // Header
                HStack(spacing: 6) {
                    Text("MONTHLY BREAKDOWN")
                        .font(.churCaption())
                        .foregroundStyle(Color.churLightGray)
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showInfoTip.toggle()
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.churLightGray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)
                
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        ZStack {
                            HStack(alignment: .bottom, spacing: 16) {
                                ForEach(1...12, id: \.self) { monthNumber in
                                    let ytdNet = (1...monthNumber).reduce(0) { total, m in
                                        total + savingsForMonth(m, selectedYear) - feesForMonth(m, selectedYear)
                                    }
                                    MonthBarView(
                                        monthLabel: numericMonths[monthNumber - 1],
                                        monthNumber: monthNumber,
                                        fees: feesForMonth(monthNumber, selectedYear),
                                        savings: savingsForMonth(monthNumber, selectedYear),
                                        maxValue: maxValue,
                                        chartAreaHeight: chartAreaHeight,
                                        isCurrentMonth: selectedYear == currentYear && monthNumber == currentMonth,
                                        cumulativeNetToDate: ytdNet,
                                        onSelect: { selectedMonth = monthNumber }
                                    )
                                    .id(monthNumber)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                    .onAppear {
                        if selectedYear == currentYear {
                            proxy.scrollTo(currentMonth, anchor: .center)
                        }
                    }
                    .onChange(of: selectedYear) {
                        if selectedYear == currentYear {
                            withAnimation {
                                proxy.scrollTo(currentMonth, anchor: .center)
                            }
                        } else {
                            withAnimation {
                                proxy.scrollTo(1, anchor: .leading)
                            }
                        }
                    }
                }
                .background(Color.churOffWhite)
            }
            
            // Floating tooltip above everything
            if showInfoTip {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showInfoTip = false
                        }
                    }
                
                VStack(alignment: .leading, spacing: 6) {
                    Label("Green bar — benefits redeemed that month", systemImage: "arrow.up")
                        .foregroundStyle(.green)
                    Label("Red bar — annual fees charged that month", systemImage: "arrow.down")
                        .foregroundStyle(.red)
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
                .padding(.horizontal, 24)
                .padding(.top, 30)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            }
        }
    }
}
