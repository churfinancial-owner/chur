//
//  ChurCancelButton.swift
//  Chur
//
//  The dismiss-without-saving action, paired with `ChurDoneButton`.
//
//  Replaces `.foregroundStyle(.red)` at every call site: one deliberate red
//  (`churRoseDeep`, #BA1A1A) rather than the system's, which shifts with the
//  platform and never matched anything else here.
//
//  Filled, the same shape and height as Done — they share `churActionChrome`,
//  so the padding cannot drift between them. The colour is what separates
//  them, not the weight.
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
                .churActionChrome(emphasis: emphasis, tint: Color.churRoseDeep)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
