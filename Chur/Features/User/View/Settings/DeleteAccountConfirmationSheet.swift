//
//  DeleteAccountConfirmationSheet.swift
//  Chur
//

import SwiftUI

struct DeleteAccountConfirmationSheet: View {
    let title: String
    let message: String
    let confirmWord: String
    let buttonLabel: String
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmationText = ""
    @FocusState private var fieldFocused: Bool

    private var isConfirmed: Bool { confirmationText == confirmWord }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.churError)
                    .padding(.top, 32)

                Text(title)
                    .font(.title2.bold())

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.churMediumGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("Type **\(confirmWord)** to confirm")
                    .font(.subheadline)
                    .foregroundStyle(Color.churMediumGray)

                TextField(confirmWord, text: $confirmationText)
                    .focused($fieldFocused)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isConfirmed ? Color.churError.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )
            }
            .padding(.horizontal)

            VStack(spacing: 10) {
                Button {
                    onConfirm()
                    dismiss()
                } label: {
                    Text(buttonLabel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.churError)
                .controlSize(.large)
                .disabled(!isConfirmed)

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.primary)
            }
            .padding(.horizontal)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear { fieldFocused = true }
    }
}
