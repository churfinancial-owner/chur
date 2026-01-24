//
//  ApprovedDatePickerSheet.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import SwiftUI

struct ApprovedDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var card: CreditCard
    
    @State private var selectedMonth: Int
    @State private var selectedYear: Int
    
    init(card: CreditCard) {
        self.card = card
        _selectedMonth = State(initialValue: card.approvedMonth)
        _selectedYear = State(initialValue: card.approvedYear)
    }
    
    let monthNames = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]
    
    var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 20)...currentYear).reversed()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 0) {
                        Text("🗓️").font(.churBigTitle2())
                        Text("Choose when this card was approved.")
                            .font(.churCaptionRegular())
                            .foregroundStyle(Color.churMediumGray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                }

                Section {
                    HStack(spacing: 0) {
                        Picker("Month", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(monthNames[month - 1]).tag(month)
                            }
                        }
                        .pickerStyle(.wheel)
                        
                        Picker("Year", selection: $selectedYear) {
                            ForEach(availableYears, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                    .frame(height: 120)
                }
            }
            .navigationTitle("Approved Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        card.approvedMonth = selectedMonth
                        card.approvedYear = selectedYear
                        dismiss()
                    }
                    .foregroundStyle(Color.churOlive)
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .height(350)])
        .presentationDragIndicator(.visible)
    }
}
