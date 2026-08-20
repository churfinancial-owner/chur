//
//  ChurCancelButton.swift
//  Chur
//
//  The dismiss-without-saving action, paired with `ChurDoneButton`.
//
//  **Tinted, not filled, and that is the point.** Done is a filled sage
//  capsule; making Cancel a filled red one would give backing out the same
//  visual weight as confirming, and put two competing blocks of colour in one
//  toolbar. Same shape, same size, one step down in emphasis.
//
//  Replaces `.foregroundStyle(.red)` at every call site — the system red is a
//  saturated primary that has nothing to do with this palette, and it read as
//  an error rather than as a choice. `churRoseDeep` is the counterpart to
//  `churSageDeep` at the same depth.
//

import SwiftUI

struct ChurCancelButton: View {
    var title: String = "Cancel"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.churRowText())
                .fontWeight(.bold)
                .foregroundStyle(Color.churRoseDeep)
                .lineLimit(1)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Color.churRoseDeep.opacity(0.12), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
