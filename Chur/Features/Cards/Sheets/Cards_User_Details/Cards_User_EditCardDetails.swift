//
//  Cards_User_EditCardDetails.swift
//  Chur
//
//  Created by Pak Ho on 2/7/26.
//

import SwiftUI
import SwiftData

struct CardsUserEditCardDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var card: CreditCard

    // MARK: - Form State
    @State private var selectedNetwork: String
    @State private var selectedCardType: String
    @State private var noteText: String

    // MARK: - Defaults

    private var defaultName: String {
        CardDatabase.getCard(id: card.templateID ?? "")?.name ?? card.name
    }

    private var defaultIssuer: String {
        CardDatabase.getCard(id: card.templateID ?? "")?.issuer ?? card.issuer
    }

    private var defaultNetwork: String {
        CardDatabase.getCard(id: card.templateID ?? "")?.network ?? card.network
    }

    private var defaultNetworkOption: String {
        Self.networkOptionLabel(from: defaultNetwork)
    }

    private var isNetworkDefault: Bool { selectedNetwork == defaultNetworkOption }
    private let baseNetworkOptions = ["Visa", "Mastercard", "Discover", "Amex", "JCB", "UnionPay"]
    private var networkOptions: [String] {
        if baseNetworkOptions.contains(selectedNetwork) {
            return baseNetworkOptions
        }
        return [selectedNetwork] + baseNetworkOptions
    }

    private var defaultCardType: String {
        CardDatabase.getCard(id: card.templateID ?? "")?.cardType ?? card.cardType
    }

    private var defaultCardTypeOption: String {
        Self.cardTypeOptionValue(from: defaultCardType)
    }

    private var isCardTypeDefault: Bool { selectedCardType == defaultCardTypeOption }
    private let baseCardTypeOptions = ["personal", "business", "student", "authorized_user"]
    private var cardTypeOptions: [String] {
        if baseCardTypeOptions.contains(selectedCardType) {
            return baseCardTypeOptions
        }
        return [selectedCardType] + baseCardTypeOptions
    }

    // MARK: - Init

    init(card: CreditCard) {
        self.card = card
        _selectedNetwork = State(initialValue: Self.networkOptionLabel(from: card.network))
        _selectedCardType = State(initialValue: Self.cardTypeOptionValue(from: card.cardType))
        _noteText = State(initialValue: card.note)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // MARK: Notes Section
                Section("Card Notes") {
                    VStack(alignment: .leading, spacing: 10) {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $noteText)
                                .frame(minHeight: 90, maxHeight: 140)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(Color.churDarkGray)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            if noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Add a note to show on the card art")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(Color.churMediumGray)
                                    .padding(.top, 14)
                                    .padding(.leading, 14)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Card Information Section
                Section("Card Information") {
                    readOnlyRow(label: "Issuer", value: card.issuer)
                    readOnlyRow(label: "Card Name", value: card.name)

                    // Network Row
                    networkSelectionRow()

                    // Card Type Row
                    cardTypeSelectionRow()
                }
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        card.network = selectedNetwork
                        card.cardType = selectedCardType
                        card.note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                        .foregroundStyle(Color.churOlive)
                        .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Network Row
    @ViewBuilder
    private func networkSelectionRow() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Network")
                        .font(.churRowText())
                        .foregroundStyle(Color.churDarkGray)
                    if !isNetworkDefault {
                        Text("Custom value")
                            .font(.churSmall())
                            .foregroundStyle(Color.churWarning)
                    }
                }

                Spacer()

                Menu {
                    ForEach(networkOptions, id: \.self) { option in
                        Button(option) {
                            selectedNetwork = option
                        }
                    }
                } label: {
                    editableMenuValueLabel(selectedNetwork)
                }
            }

            if !isNetworkDefault {
                Button {
                    selectedNetwork = defaultNetworkOption
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.churSmall())
                        Text("Reset to default (\(defaultNetworkOption))")
                            .font(.churSmall())
                    }
                    .foregroundStyle(Color.churWarning)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Card Type Row
    @ViewBuilder
    private func cardTypeSelectionRow() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Card Type")
                        .font(.churRowText())
                        .foregroundStyle(Color.churDarkGray)
                    if !isCardTypeDefault {
                        Text("Custom value")
                            .font(.churSmall())
                            .foregroundStyle(Color.churWarning)
                    }
                }

                Spacer()

                Menu {
                    ForEach(cardTypeOptions, id: \.self) { option in
                        Button(Self.cardTypeDisplayLabel(for: option)) {
                            selectedCardType = option
                        }
                    }
                } label: {
                    editableMenuValueLabel(Self.cardTypeDisplayLabel(for: selectedCardType))
                }
            }

            if !isCardTypeDefault {
                Button {
                    selectedCardType = defaultCardTypeOption
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.churSmall())
                        Text("Reset to default (\(Self.cardTypeDisplayLabel(for: defaultCardTypeOption)))")
                            .font(.churSmall())
                    }
                    .foregroundStyle(Color.churWarning)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func editableMenuValueLabel(_ value: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.churRowText())
                .foregroundStyle(Color.churOlive)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.churOlive)
        }
    }

    private static func networkOptionLabel(from rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        switch normalized {
        case "americanexpress", "amex":
            return "Amex"
        case "mastercard", "mc":
            return "Mastercard"
        case "visa":
            return "Visa"
        case "discover":
            return "Discover"
        case "jcb":
            return "JCB"
        case "unionpay", "union pay":
            return "UnionPay"
        default:
            return trimmed.isEmpty ? "Visa" : trimmed
        }
    }

    private static func cardTypeOptionValue(from rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")

        switch normalized {
        case "personal":
            return "personal"
        case "business":
            return "business"
        case "student":
            return "Student"
        case "authorized_user", "authorizeduser":
            return "authorized_user"
        default:
            return trimmed.isEmpty ? "personal" : normalized
        }
    }

    private static func cardTypeDisplayLabel(for option: String) -> String {
        switch option {
        case "personal":
            return "Personal"
        case "business":
            return "Business"
        case "student":
            return "Student"
        case "authorized_user":
            return "Authorized User"
        default:
            return option
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    // MARK: - Read-Only Row Builder
    @ViewBuilder
    private func readOnlyRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.churRowText())
                .foregroundStyle(Color.churDarkGray)

            Spacer()

            Text(value)
                .font(.churRowText())
                .foregroundStyle(Color.churOlive)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}
