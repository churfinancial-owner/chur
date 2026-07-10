import SwiftUI

struct ApprovedDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var card: CreditCard

    @State private var selectedDate: Date

    init(card: CreditCard) {
        self.card = card
        let components = DateComponents(
            year: card.approvedYear,
            month: card.approvedMonth,
            day: card.approvedDay
        )
        _selectedDate = State(initialValue: Calendar.current.date(from: components) ?? Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    calendarSection
                    Spacer(minLength: 32)
                }
                .padding()
            }
            .background(Color.churOffWhite)
            .navigationTitle("Approved Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.red)
                        .fontWeight(.bold)
                        .font(.churRowText())
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
                        card.approvedMonth = components.month ?? card.approvedMonth
                        card.approvedDay = components.day ?? card.approvedDay
                        card.approvedYear = components.year ?? card.approvedYear
                        dismiss()
                    }
                    .font(.churRowText())
                    .fontWeight(.bold)
                    .foregroundStyle(Color.churOlive)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("🗓️").font(.churBigTitle1())
            Text("Choose when this card was approved.")
                .font(.churCaptionRegular())
                .foregroundStyle(Color.churMediumGray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("APPROVAL DATE")
                .font(.churSmallBold())
                .foregroundStyle(Color.churOlive)
                .tracking(0.5)

            DatePicker(
                "",
                selection: $selectedDate,
                in: .distantPast...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Color.churOlive)
            .padding(8)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }
}
