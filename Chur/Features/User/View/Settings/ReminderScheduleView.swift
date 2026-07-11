//
//  ReminderScheduleView.swift
//  Chur
//
//  Subpage of Notification settings: per-cycle benefit reminder lead
//  times plus the annual fee lead time (see ReminderTiming), with a
//  reset back to the recommended defaults.
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
                ForEach(ReminderTiming.Cycle.allCases) { cycle in
                    LeadDaysPickerRow(
                        title: cycle.displayName,
                        options: cycle.options,
                        current: ReminderTiming.leadDays(for: cycle),
                        save: { ReminderTiming.setLeadDays($0, for: cycle) },
                        onChanged: { isRecommended = ReminderTiming.isRecommended }
                    )
                }
                .id(resetTick)
            } header: {
                Text("BENEFITS — DAYS BEFORE EXPIRY")
            } footer: {
                Text("How long before expiry each benefit shows the ⏰ badge and sends a reminder. A final reminder is also sent 1–3 days before longer cycles expire. When several benefits expire on the same day, they arrive as one summary notification.")
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
                Text("A final notice is also sent 7 days before the fee posts.")
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
                Text("\(days) day\(days == 1 ? "" : "s")").tag(days)
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
