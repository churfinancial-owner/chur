//
//  ChurDoneButton.swift
//  Chur
//
//  The confirm action for every sheet: a filled sage capsule.
//
//  There were 22 hand-rolled "Done" buttons before this, each repeating
//  `.font(.churRowText()).fontWeight(.bold).foregroundStyle(Color.churOlive)`,
//  and they had already drifted — some olive, some conditionally grey, one a
//  full CTA with a count badge. A confirm action is one thing and should look
//  like one thing.
//
//  Sized to sit inside a navigation toolbar as well as free-floating on a sage
//  hero, which is why the padding is smaller than a full-width CTA's.
//

import SwiftUI

struct ChurDoneButton: View {
    var title: String = "Done"
    /// Disabled renders grey and blocks the action — for sheets that gate
    /// confirmation on a complete selection.
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.churRowText())
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(isEnabled ? Color.churSageDeep : Color.churLightGray, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
    }
}
