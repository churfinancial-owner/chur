//
//  ChurCancelButton.swift
//  Chur
//
//  The dismiss-without-saving action, paired with `ChurDoneButton`.
//
//  Replaces `.foregroundStyle(.red)` at every call site — the system red is a
//  saturated primary with nothing to do with this palette, and it read as an
//  error rather than as a choice. `churRoseDeep` is the counterpart to
//  `churSageDeep` at the same depth.
//
//  Never filled, even when prominent: Done is the filled capsule, and matching
//  it here would give backing out the same weight as confirming.
//

import SwiftUI

struct ChurCancelButton: View {
    var title: String = "Cancel"
    var emphasis: ChurActionEmphasis = .prominent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.churRowText())
                .fontWeight(.bold)
                .lineLimit(1)
                .fixedSize()
                .churActionChrome(emphasis: emphasis, tint: Color.churRoseDeep, filled: false)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
