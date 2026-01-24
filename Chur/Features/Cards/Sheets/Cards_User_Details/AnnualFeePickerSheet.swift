//
//  AnnualFeePickerSheet.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import SwiftUI

struct AnnualFeePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var card: CreditCard

    @State private var valueText: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    private var defaultFee: Int {
        CardDatabase.getCard(id: card.templateID ?? "")?.annualFee ?? 0
    }

    private var isDefault: Bool { card.annualFee == defaultFee }

    init(card: CreditCard) {
        self.card = card
        _valueText = State(initialValue: "\(card.annualFee)")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 0) {
                        Text("💳").font(.churBigTitle2())
                        Text("Edit the fee amount if your fee is different.")
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
                                Text("Annual Fee")
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
                                    Text("$").foregroundStyle(.secondary)
                                    TextField("0", text: $valueText)
                                        .keyboardType(.numberPad)
                                        .focused($isFocused)
                                        .multilineTextAlignment(.trailing)
                                        .font(.churRowText())
                                        .foregroundStyle(Color.churOlive)
                                        .frame(width: 60)
                                }

                                Button {
                                    let newFee = Int(valueText) ?? card.annualFee
                                    card.annualFee = newFee
                                    card.hasCustomAnnualFee = newFee != defaultFee
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
                                    Text("$\(card.annualFee)")
                                        .font(.churRowText())
                                        .foregroundStyle(Color.churOlive)

                                    Button {
                                        valueText = "\(card.annualFee)"
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
                                card.annualFee = defaultFee
                                card.hasCustomAnnualFee = false
                                valueText = "\(defaultFee)"
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise").font(.churSmall())
                                    Text("Reset to default ($\(defaultFee))").font(.churSmall())
                                }
                                .foregroundStyle(Color.churWarning)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Annual Fee")
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
