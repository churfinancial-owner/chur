//
//  ChurDoneButton.swift
//  Chur
//
//  The confirm action for every sheet, paired with `ChurCancelButton`.
//
//  There were 21 hand-rolled "Done" buttons before this, each repeating
//  `.font(.churRowText()).fontWeight(.bold).foregroundStyle(Color.churOlive)`,
//  and they had already drifted — some olive, one conditionally grey.
//
//  **Two emphases, and picking the wrong one is visible.** iOS 26 wraps every
//  toolbar item in its own Liquid Glass container, so a filled capsule inside a
//  toolbar is a second container inside the first: it draws a seam around
//  itself, and a low-opacity fill washes out against the glass to the point of
//  disappearing. In a toolbar the system owns the shape and this contributes
//  only the colour; free-floating — the period sheet's hero — it draws the
//  capsule itself because nothing else will.
//

import SwiftUI

enum ChurActionEmphasis {
    /// Colour only. The toolbar's own container provides the shape.
    case toolbar
    /// Draws its own filled capsule, for buttons not inside a toolbar.
    case prominent
}

struct ChurDoneButton: View {
    var title: String = "Done"
    /// Disabled renders grey and blocks the action — for sheets that gate
    /// confirmation on a complete selection.
    var isEnabled: Bool = true
    var emphasis: ChurActionEmphasis = .toolbar
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.churRowText())
                .fontWeight(.bold)
                .lineLimit(1)
                .fixedSize()
                .churActionChrome(emphasis: emphasis,
                                  tint: isEnabled ? Color.churSageDeep : Color.churLightGray,
                                  filled: true)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
    }
}

// MARK: - Shared chrome

extension View {

    /// The one place the two emphases differ, so Done and Cancel cannot drift.
    @ViewBuilder
    func churActionChrome(emphasis: ChurActionEmphasis, tint: Color, filled: Bool) -> some View {
        switch emphasis {
        case .toolbar:
            foregroundStyle(tint)
        case .prominent:
            foregroundStyle(filled ? Color.white : tint)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(filled ? tint : tint.opacity(0.12), in: Capsule())
        }
    }
}
