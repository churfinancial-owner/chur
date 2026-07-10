//
//  GoogleSignInButton.swift
//  Chur
//
//  Custom SwiftUI button matching Google's sign-in branding.
//

import SwiftUI

struct GoogleSignInButtonWrapper: View {
    var action: () -> Void

    // Official Google Blue: #4285F4
    private let googleBlue = Color(red: 66/255, green: 133/255, blue: 244/255)
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) { // Spacing between logo and text
                // The Google "G" logo
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 28, height: 28)
                    
                    Text("G")
                        .font(.churHeadline())
                        .foregroundStyle(googleBlue)
                }
                
                Text("Sign in with Google")
                    .font(.churHeadlineMedium())
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 50) // Match Apple button height
            .background(googleBlue)
            .clipShape(RoundedRectangle(cornerRadius: 14)) // Match Apple button radius
        }
        .buttonStyle(.plain)
    }
}
