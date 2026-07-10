//
//  EmptyStatePlaceholder.swift
//  Chur
//

import SwiftUI

struct EmptyStatePlaceholder: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.churBigTitle3())
                .foregroundStyle(Color.churMediumGray)
            Text(title)
                .font(.churSectionHeader())
                .foregroundStyle(Color.churDarkGray)
            Text(subtitle)
                .font(.churSmallMedium())
                .foregroundStyle(Color.churMediumGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}
