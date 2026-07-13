//
//  ReminderScheduleView.swift
//  Chur
//
//  Subpage of Notification settings: one benefit reminder lead time (all
//  frequencies) plus the annual fee lead time (see ReminderTiming), with
//  a reset back to the recommended defaults.
//

import SwiftUI
import SwiftData

struct ReminderScheduleView: View {
    @Environment(\.modelContext) private var modelContext

    /// Bumped on reset so the picker rows re-read their stored values.
    @State private var resetTick = 0
    @State private var isRecommended = ReminderTiming.isRecommended

    var body: some View {
        List {
            Section {
                LeadDaysPickerRow(
                    title: "Benefits",
                    options: ReminderTiming.benefitOptions,
                    current: ReminderTiming.benefitLeadDays,
                    save: { ReminderTiming.setBenefitLeadDays($0) },
                    onChanged: { isRecommended = ReminderTiming.isRecommended }
                )
                .id(resetTick)
            } header: {
                Text("BENEFITS — DAYS BEFORE EXPIRY")
            } footer: {
                Text("One schedule for every benefit: this is when the ⏰ badge appears, when the single reminder is sent, and what the Expiring Soon list shows. When several benefits expire around the same day, they arrive as one summary notification.")
            }

            Section {
                LeadDaysPickerRow(
                    title: "Annual fee",
                    options: ReminderTiming.AnnualFee.options,
                    current: ReminderTiming.annualFeeLeadDays,
                    save: { ReminderTiming.setAnnualFeeLeadDays($0) },
                    onChanged: { isRecommended = ReminderTiming.isRecommended }
                )
                .id(resetTick)
            } header: {
                Text("ANNUAL FEE — DAYS BEFORE IT POSTS")
            } footer: {
                Text("One notice per card each year.")
            }

            Section {
                Button {
                    withAnimation {
                        ReminderTiming.resetToRecommended()
                        resetTick += 1
                        isRecommended = true
                    }
                    ReminderScheduler.shared.requestReconcile(context: modelContext)
                } label: {
                    Text("Reset to Recommended")
                        .font(.churRowText())
                        .foregroundStyle(isRecommended ? Color.churMediumGray : Color.churOlive)
                }
                .disabled(isRecommended)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.churOffWhite)
        .navigationTitle("Reminder Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Lead-Days Picker Row

private struct LeadDaysPickerRow: View {
    let title: String
    let options: [Int]
    let save: (Int) -> Void
    var onChanged: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var selection: Int

    init(title: String, options: [Int], current: Int,
         save: @escaping (Int) -> Void, onChanged: @escaping () -> Void) {
        self.title = title
        self.options = options
        self.save = save
        self.onChanged = onChanged
        self._selection = State(initialValue: current)
    }

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { days in
                Text(days == 0 ? "On the day" : "\(days) day\(days == 1 ? "" : "s")").tag(days)
            }
        }
        .font(.churRowText())
        .tint(Color.churOlive)
        .onChange(of: selection) { _, newValue in
            save(newValue)
            ReminderScheduler.shared.requestReconcile(context: modelContext)
            onChanged()
        }
    }
}
