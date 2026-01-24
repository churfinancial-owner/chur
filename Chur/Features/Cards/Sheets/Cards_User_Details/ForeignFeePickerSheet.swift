//
//  ForeignFeePickerSheet.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import SwiftUI

struct ForeignFeePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var card: CreditCard

    @State private var valueText: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    private var defaultRate: Double? {
        CardDatabase.getCard(id: card.templateID ?? "")?.foreignTransactionFeeRate
    }

    private var isDefault: Bool {
        card.foreignTransactionFeeRate == defaultRate &&
        card.hasForeignTransactionFee == (defaultRate != nil && defaultRate! > 0)
    }

    private static func format(_ rate: Double?) -> String {
        guard let r = rate, r > 0 else { return "0" }
        let pct = r * 100
        return pct.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", pct) : String(format: "%.2f", pct)
    }

    private var displayValue: String {
        guard card.hasForeignTransactionFee, let r = card.foreignTransactionFeeRate, r > 0 else { return "None" }
        return "\(Self.format(r))%"
    }

    private var defaultDisplayValue: String {
        guard let r = defaultRate, r > 0 else { return "None" }
        return "\(Self.format(r))%"
    }

    init(card: CreditCard) {
        self.card = card
        _valueText = State(initialValue: Self.format(card.foreignTransactionFeeRate))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 0) {
                        Text("🌍").font(.churBigTitle2())
                        Text("Override the default foreign transaction fee for this card.")
                            .font(.churFootnote())
                            .foregroundStyle(Color.churMediumGray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Foreign Transaction Fee")
                                    .font(.churRowText())
                                    .foregroundStyle(Color.churDarkGray)
                                if !isDefault {
                                    Text("Custom value")
                                        .font(.churSmallBold())
                                        .foregroundStyle(Color.churWarning)
                                }
                            }

                            Spacer()

                            if isEditing {
                                HStack(spacing: 4) {
                                    TextField("0", text: $valueText)
                                        .keyboardType(.decimalPad)
                                        .focused($isFocused)
                                        .multilineTextAlignment(.trailing)
                                        .font(.churRowText())
                                        .foregroundStyle(Color.churOlive)
                                        .frame(width: 60)
                                    Text("%").foregroundStyle(.secondary)
                                }

                                Button {
                                    let parsed = Double(valueText) ?? 0
                                    let newRate = parsed > 0 ? parsed / 100.0 : nil
                                    card.hasForeignTransactionFee = parsed > 0
                                    card.foreignTransactionFeeRate = newRate
                                    card.hasCustomForeignFee = newRate != defaultRate
                                    isEditing = false
                                } label: {
                                    Text("Confirm")
                                        .font(.churRowText())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.churOlive, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            } else {
                                HStack(spacing: 4) {
                                    Text(displayValue)
                                        .font(.churRowText())
                                        .foregroundStyle(Color.churOlive)

                                    Button {
                                        valueText = Self.format(card.foreignTransactionFeeRate)
                                        isEditing = true
                                        isFocused = true
                                    } label: {
                                        Image(systemName: "pencil.circle")
                                            .foregroundStyle(Color.churMediumGray)
                                            .font(.churBigTitle4())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if !isDefault && !isEditing {
                            Button {
                                let r = defaultRate ?? 0
                                card.hasForeignTransactionFee = r > 0
                                card.foreignTransactionFeeRate = r > 0 ? r : nil
                                card.hasCustomForeignFee = false
                                valueText = Self.format(defaultRate)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise").font(.churSmall())
                                    Text("Reset to default (\(defaultDisplayValue))").font(.churSmall())
                                }
                                .foregroundStyle(Color.churWarning)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Foreign Transaction Fee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.churOlive)
                        .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
