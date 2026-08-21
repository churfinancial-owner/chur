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
//  **The capsule is the style everywhere — including toolbars.** iOS 26 wraps
//  each toolbar item in its own Liquid Glass container, which drew a seam
//  around the capsule and washed out a tinted fill. The container is what gets
//  suppressed, with `.churBareToolbarBackground()` on the `ToolbarItem`; the
//  button is unchanged. `.toolbar` emphasis (colour only, no capsule) stays
//  available for anywhere the system chrome should win, but nothing uses it
//  today.
//

import SwiftUI

enum ChurActionEmphasis {
    /// Colour only — for a host whose own chrome should provide the shape.
    case toolbar
    /// The capsule. The default, and what every call site uses.
    case prominent
}

// MARK: - Toolbar hosting

extension ToolbarContent {

    /// Drops iOS 26's Liquid Glass container from a toolbar item.
    ///
    /// Without it the item's own glass capsule sits behind ours and shows as a
    /// seam around the button, and `ChurCancelButton`'s tinted fill washes out
    /// against it far enough to look unrendered.
    ///
    /// Deliberately the only reference to this API in the app: if the name or
    /// signature moves, one line changes rather than thirty.
    @ToolbarContentBuilder
    func churBareToolbarBackground() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

struct ChurDoneButton: View {
    var title: String = "Done"
    /// Disabled renders grey and blocks the action — for sheets that gate
    /// confirmation on a complete selection.
    var isEnabled: Bool = true
    var emphasis: ChurActionEmphasis = .prominent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.churRowText())
                .fontWeight(.bold)
                .lineLimit(1)
                .fixedSize()
                .churActionChrome(emphasis: emphasis,
                                  tint: isEnabled ? Color.churSageDeep : Color.churLightGray)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
    }
}

// MARK: - Shared chrome

extension View {

    /// The one place the two emphases differ, so Done and Cancel cannot drift.
    ///
    /// Both are filled, and both run this identical padding — which is what
    /// guarantees they are the same height. A tinted Cancel was tried and
    /// dropped: against the toolbar it read as weaker than Done rather than as
    /// a peer, and the two fills sit at the same depth so neither shouts.
    @ViewBuilder
    func churActionChrome(emphasis: ChurActionEmphasis, tint: Color) -> some View {
        switch emphasis {
        case .toolbar:
            foregroundStyle(tint)
        case .prominent:
            foregroundStyle(Color.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(tint, in: Capsule())
        }
    }
}
