//
//  timetravelsheet.swift
//  Chur
//
//  Created by Pak Ho on 3/9/26.
//

import SwiftUI
import SwiftData

// MARK: - TIME TRAVEL SHEET (DELETE LATER)
#if DEBUG

struct TimeTravelSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Seed the picker with the current mock date, or real time if none is set.
    @State private var selectedDate: Date = TestDataConfiguration.mockCurrentDate ?? Date()
    @State private var isTimeTravelActive: Bool = TestDataConfiguration.mockCurrentDate != nil

    private static let presets: [(title: String, year: Int, month: Int, day: Int, hour: Int)] = [
        ("Feb 28 — Month End",     2026, 2,  28, 23),
        ("Mar 1 — New Month",      2026, 3,  1,  8),
        ("Mar 31 — Q1 End",        2026, 3,  31, 23),
        ("Apr 1 — Q2 Start",       2026, 4,  1,  8),
        ("Jun 30 — H1 End",        2026, 6,  30, 23),
        ("Jul 1 — H2 Start",       2026, 7,  1,  8),
        ("Sep 30 — Q3 End",        2026, 9,  30, 23),
        ("Dec 31 — Year End",      2026, 12, 31, 23),
        ("Jan 1 — New Year",       2027, 1,  1,  8),
    ]

    var body: some View {
        NavigationStack {
            List {

                // MARK: Status Banner
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: isTimeTravelActive ? "clock.arrow.circlepath" : "clock")
                            .font(.churTitle())
                            .foregroundStyle(isTimeTravelActive ? Color.orange : Color.churMediumGray)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(isTimeTravelActive ? "Time Travel Active" : "Using Real Time")
                                .font(.churRowText())
                                .foregroundStyle(isTimeTravelActive ? Color.orange : Color.churDarkGray)
                            Text(isTimeTravelActive ? selectedDate.formatted(date: .long, time: .shortened) : Date().formatted(date: .long, time: .shortened))
                                .font(.churFootnote())
                                .foregroundStyle(Color.churMediumGray)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Calendar Picker
                Section("Pick a Date & Time") {
                    DatePicker(
                        "Travel To",
                        selection: $selectedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .onChange(of: selectedDate) { _, newDate in
                        TestDataConfiguration.mockCurrentDate = newDate
                        TestDataConfiguration.notifyDateChanged()
                        isTimeTravelActive = true
                    }
                }

                // MARK: Quick Presets
                Section("Quick Presets") {
                    ForEach(Self.presets, id: \.title) { preset in
                        Button {
                            applyPreset(preset)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.title)
                                        .font(.churRowTextMedium())
                                        .foregroundStyle(Color.churDarkGray)
                                    if let date = Calendar.current.date(from: DateComponents(
                                        year: preset.year, month: preset.month,
                                        day: preset.day, hour: preset.hour)) {
                                        Text(date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(Color.churMediumGray)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Color.churMediumGray)
                            }
                        }
                    }
                }

                // MARK: ≈
                Section {
                    Button(role: .destructive) {
                        TestDataConfiguration.resetToRealTime()
                        selectedDate = Date()
                        isTimeTravelActive = false
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Real Time")
                        }
                    }
                }
            }
            .navigationTitle("⏰ Time Travel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func applyPreset(_ preset: (title: String, year: Int, month: Int, day: Int, hour: Int)) {
        TestDataConfiguration.setMockDate(
            year: preset.year,
            month: preset.month,
            day: preset.day,
            hour: preset.hour
        )
        if let date = TestDataConfiguration.mockCurrentDate {
            selectedDate = date
        }
        isTimeTravelActive = true
    }
}
#endif

