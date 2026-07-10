import SwiftUI

struct CardTypePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var card: CreditCard
    let options = ["personal", "business", "student", "authorized_user"]

    private var defaultCardType: String {
        CardInformationSection.cardTypeOptionValue(
            from: CardDatabase.getCard(id: card.templateID ?? "")?.cardType ?? card.cardType
        )
    }

    private var currentCardType: String {
        CardInformationSection.cardTypeOptionValue(from: card.cardType)
    }

    private var isDefault: Bool { currentCardType == defaultCardType }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    optionsSection
                    Spacer(minLength: 32)
                }
                .padding()
            }
            .background(Color.churOffWhite)
            .navigationTitle("Card Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
            Text("🖋️").font(.churBigTitle1())
            Text("Select the account type for this card.")
                .font(.churCaptionRegular())
                .foregroundStyle(Color.churMediumGray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CARD TYPE")
                .font(.churSmallBold())
                .foregroundStyle(Color.churOlive)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    Button {
                        card.cardType = option
                    } label: {
                        HStack(spacing: 10) {
                            Text(CardInformationSection.cardTypeDisplayLabel(for: option))
                                .font(.churRowText())
                                .foregroundStyle(Color.churDarkGray)
                            if option == defaultCardType {
                                defaultBadge
                            }
                            Spacer()
                            Image(systemName: currentCardType == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(currentCardType == option ? Color.churOlive : Color.churLightGray.opacity(0.5))
                                .font(.churBigTitle4())
                        }
                        .padding(16)
                    }
                    .buttonStyle(.plain)

                    if option != options.last {
                        Divider().padding(.horizontal, 16).opacity(0.5)
                    }
                }

                if !isDefault {
                    Divider().padding(.horizontal, 16).opacity(0.5)

                    Button {
                        card.cardType = defaultCardType
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise").font(.churSmall())
                            Text("Reset to default (\(CardInformationSection.cardTypeDisplayLabel(for: defaultCardType)))").font(.churSmall())
                        }
                        .foregroundStyle(Color.churWarning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    private var defaultBadge: some View {
        Text("Default")
            .font(.churBadgeBold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.churOlive.opacity(0.7))
            .clipShape(Capsule())
    }
}
