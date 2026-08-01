//
//  ToolSheetHeaderBanner.swift
//  Chur
//
//  Shared header banner for full-screen tool sheets (Couponing, Transfer Partners,
//  Year Summary, and future ones) — replaces the old photographic/illustrated
//  PatternHeaderBanner with a flat white dot-pattern background. Owns the
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
                    Color.churBannerBackground
                    DotPatternBackground()
                }
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
            }
            .overlay(alignment: .topTrailing) {
                closeButton
                    .padding(.top, 14)
                    .padding(.trailing, 16)
            }
            .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Text("✕")
                .font(.churFootnote())
                .foregroundStyle(Color.churDarkGray)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.7))
                .clipShape(Circle())
        }
    }
}

/// Repeating dot pattern — white, 2pt radius, on a 16x16pt grid.
private struct DotPatternBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 16
            let dotRadius: CGFloat = 2
            let dotColor = Color.white

            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}
