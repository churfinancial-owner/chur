//
//  OnboardingProfileStep.swift
//  Chur
//
//  Step 5: Set name and profile photo.
//

import SwiftUI

struct OnboardingProfileStep: View {
    @Binding var firstName: String
    @Binding var profilePhotoData: Data?
    let onFinish: () -> Void

    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                // Photo avatar picker
                VStack(spacing: 10) {
                    ProfilePhotoPicker(profilePhotoData: $profilePhotoData, diameter: 130)

                    Text(profilePhotoData == nil ? "Tap to add a profile photo" : "Tap to change photo")
                        .font(.churMicro())
                        .foregroundStyle(Color.churMediumGray)
                }

                // Name field
                VStack(spacing: 8) {
                    Text("What should we call you?")
                        .font(.churHeadline())
                        .foregroundStyle(Color.churDarkGray)

                    TextField("Your name", text: $firstName)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.churLightGray, lineWidth: 1)
                        )
                        .focused($isNameFocused)
                        .padding(.horizontal, 40)
                }
            }

            Spacer()

            // Finish button
            Button {
                isNameFocused = false
                onFinish()
            } label: {
                Text("Finish Setup")
                    .font(.churHeadline())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.churOlive)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onTapGesture {
            isNameFocused = false
        }
    }
}
