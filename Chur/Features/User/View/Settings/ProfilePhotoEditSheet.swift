//
//  ProfilePhotoEditSheet.swift
//  Chur
//

import SwiftUI

struct ProfilePhotoEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var user: User

    var body: some View {
        NavigationStack {
            VStack {
                ProfilePhotoPicker(
                    profilePhotoData: $user.profilePhotoData,
                    profileEmoji: $user.profileEmoji,
                    diameter: 120
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.churOffWhite)
            .navigationTitle("Profile Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    ChurDoneButton { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
