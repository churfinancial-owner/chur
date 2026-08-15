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
/// Displays the brand icon if there is one, otherwise falls back to the emoji.
///
/// Icons stopped shipping in the binary in P1d, so this resolves through
/// `IconArtView` — bundle, then cache, then CDN. The emoji covers both "this
/// category has no icon" and "the icon hasn't downloaded yet", which is why it
/// stays the fallback rather than a spinner: it is a complete, correct rendering
/// on its own and always has been.
struct CategoryIconView: View {
    let category: SpendingCategory
    var font: Font = .title2

    var body: some View {
        IconArtView(imageName: category.iconName) {
            Text(category.emoji)
                .font(font)
        }
    }
}
