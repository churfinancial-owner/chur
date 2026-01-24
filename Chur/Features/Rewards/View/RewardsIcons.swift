//
//  RewardsIcons.swift
//  Chur
//
//  Created by Pak Ho on 3/11/26.
//
//  Created by Pak Ho on 1/17/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Category Icon View
/// Displays the brand icon from the asset catalog if available, otherwise falls back to the emoji.
struct CategoryIconView: View {
    let category: SpendingCategory
    var font: Font = .title2

    var body: some View {
        if let iconName = category.iconName,
           let uiImage = UIImage(named: iconName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            Text(category.emoji)
                .font(font)
        }
    }
}
