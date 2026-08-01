//
//  ToolSheetHeaderBanner.swift
//  Chur
//
//  Shared header banner for full-screen tool sheets (Couponing, Transfer Partners,
//  Year Summary, and future ones) — replaces the old photographic/illustrated
//  PatternHeaderBanner with a flat off-white olive dot-pattern background. Owns the
//  banner's background, grab handle, and close button chrome only; callers pass their
//  own title/pill/subtitle content.
//
//  Design reference: "Chur User Tab - Budget.dc.html" (design_handoff_tool_sheet_banner).
//

import SwiftUI

struct ToolSheetHeaderBanner<Content: View>: View {
    /// Reserves this much height for `content` (excluding the banner's own top/bottom
    /// padding) so banners with less content — e.g. Year Summary's 2-line title+eyebrow
    /// versus Couponing's 3-line pill+title+subtitle — still render at the same overall
    /// banner height.
    var minContentHeight: CGFloat = 92
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, minHeight: minContentHeight, alignment: .topLeading)
            .padding(.top, 22)
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
            .background {
                ZStack {
                    Color.churOffWhite
                    RepeatingPatternBackground(glyph: .dot(radius: 2), color: Color.churPatternGlyph, spacing: 16)
                }
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
            }
            .overlay(alignment: .topTrailing) {
                SheetDismissButton(action: onClose)
                    .padding(.top, 2)
            }
            .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
    }
}
