//
//  ProgramValueRow.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import SwiftUI

struct ProgramValueRow: View {
    let programName: String
    let currentValue: Double
    let defaultValue: Double?
    // Changed from cardCount: Int to associatedCards: [CreditCard]
    let associatedCards: [CreditCard]
    let isDefault: Bool
    let onSave: (Double) -> Void
    let onReset: () -> Void

    @State private var valueText: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    init(programName: String, currentValue: Double, defaultValue: Double?, associatedCards: [CreditCard], isDefault: Bool, onSave: @escaping (Double) -> Void, onReset: @escaping () -> Void) {
        self.programName = programName
        self.currentValue = currentValue
        self.defaultValue = defaultValue
        self.associatedCards = associatedCards
        self.isDefault = isDefault
        self.onSave = onSave
        self.onReset = onReset
        _valueText = State(initialValue: Self.format(currentValue))
    }

    private static func format(_ value: Double) -> String {
        let pct = value * 100
        if pct.truncatingRemainder(dividingBy: 1) == 0 { return String(format: "%.0f", pct) }
        return String(format: "%.2f", pct)
    }

    private var defaultDisplayValue: String {
        guard let d = defaultValue else { return "—" }
        return "\(Self.format(d))¢"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { // Increased spacing for the card row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(programName)
                        .font(.churRowText())
                        .foregroundStyle(Color.churDarkGray)
                    
                    if !isDefault {
                        Text("Custom value")
                            .font(.churMicroBold())
                            .foregroundStyle(Color.churWarning)
                    }
                }
                
                Spacer()
                
                if isEditing {
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            TextField("1.25", text: $valueText)
                                .keyboardType(.decimalPad)
                                .focused($isFocused)
                                .multilineTextAlignment(.trailing)
                                .font(.churRowText())
                                .foregroundStyle(Color.churOlive)
                                .frame(width: 50)
                            Text("¢").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                        }

                        Button {
                            if let parsed = Double(valueText), parsed > 0 {
                                onSave(parsed / 100.0)
                            }
                            isEditing = false
                        } label: {
                            Text("Save")
                                .font(.churFootnoteBold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.churOlive, in: Capsule())
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Text("\(Self.format(currentValue))¢")
                            .font(.churRowText())
                            .foregroundStyle(Color.churOlive)

                        Button {
                            valueText = Self.format(currentValue)
                            isEditing = true
                            isFocused = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(Color.churMediumGray.opacity(0.6))
                                .font(.churBigTitle4())
                        }
                    }
                }
            }

            // MARK: - Individual Card Logos & Names
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(associatedCards) { card in
                        HStack(spacing: 6) {
                            CardThumbnailView(card: card, width: 32, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
                            
                            Text(card.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.churMediumGray)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.churOffWhite)
                        .clipShape(Capsule())
                    }
                }
            }

            if !isDefault && !isEditing {
                Button {
                    onReset()
                    if let d = defaultValue {
                        valueText = Self.format(d)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise").font(.churBadge())
                        Text("Reset to default (\(defaultDisplayValue))").font(.churBadge())
                    }
                    .foregroundStyle(Color.churWarning)
                    .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}
