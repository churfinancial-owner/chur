//
//  ReminderScheduleView.swift
//  Chur
//
//  Subpage of Notification settings: per-cycle reminder lead times
//  (see ReminderTiming) with a reset back to the recommended defaults.
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
                    ReminderTimingPickerRow(cycle: cycle) {
                        isRecommended = ReminderTiming.isRecommended
                    }
                }
                .id(resetTick)
            } header: {
                Text("DAYS BEFORE EXPIRY")
            } footer: {
                Text("How long before expiry each benefit shows the ⏰ badge and sends a reminder. A final reminder is also sent 1–3 days before longer cycles expire.")
            }

            Section {
                Button {
                    withAnimation {
                        ReminderTiming.resetToRecommended()
                        resetTick += 1
                        isRecommended = true
                    }
                    BenefitReminderScheduler.shared.requestReconcile(context: modelContext)
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

// MARK: - Timing Picker Row

private struct ReminderTimingPickerRow: View {
    let cycle: ReminderTiming.Cycle
    var onChanged: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var selection: Int

    init(cycle: ReminderTiming.Cycle, onChanged: @escaping () -> Void) {
        self.cycle = cycle
        self.onChanged = onChanged
        self._selection = State(initialValue: ReminderTiming.leadDays(for: cycle))
    }

    var body: some View {
        Picker(cycle.displayName, selection: $selection) {
            ForEach(cycle.options, id: \.self) { days in
                Text("\(days) day\(days == 1 ? "" : "s")").tag(days)
            }
        }
        .font(.churRowText())
        .tint(Color.churOlive)
        .onChange(of: selection) { _, newValue in
            ReminderTiming.setLeadDays(newValue, for: cycle)
            BenefitReminderScheduler.shared.requestReconcile(context: modelContext)
            onChanged()
        }
    }
}
