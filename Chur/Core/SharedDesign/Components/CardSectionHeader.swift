//
//  CardSectionHeader.swift
//  Chur
//
//  The section header and row divider used by Card Info, and now by
//  `ChurMenuSheet` so a menu reads like the lists it sits beside.
//
//  Moved here from `Features/Cards/View/Info/CardInfoView.swift` when the menu
//  sheet needed them: `Core` must not reach into a feature, and two consumers
//  is what makes something design-system rather than feature-local.
//

import SwiftUI

struct CardSectionHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.churSmallBold())
                .foregroundStyle(Color.churOlive)
                .tracking(1.0)
                .padding([.horizontal, .top], 20)
                .padding(.bottom, 12)
            Divider().padding(.horizontal, 20)
        }
    }
}

struct CardRowDivider: View {
    var body: some View {
        Divider().padding(.horizontal, 4).opacity(0.4)
    }
}
