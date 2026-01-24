//
//  BenefitComponents.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import SwiftUI

/// Shared UI row for the info cards
struct BenefitInfoRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.churBigTitle4())
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.churBadgeBold())
                    .foregroundStyle(Color.churMediumGray)
                Text(value)
                    .font(.churSectionHeader())
                    .foregroundStyle(Color.churDarkGray)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
