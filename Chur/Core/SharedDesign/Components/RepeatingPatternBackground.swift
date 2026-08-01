//
//  RepeatingPatternBackground.swift
//  Chur
//
//  Shared repeating background pattern for header banners — a grid of dots
//  (ToolSheetHeaderBanner) or a repeating glyph like "$" (MerchantDetailSheet).
//

import SwiftUI

enum PatternGlyph {
    case dot(radius: CGFloat = 2)
    case symbol(String, font: Font)
}

struct RepeatingPatternBackground: View {
    var glyph: PatternGlyph
    var color: Color
    var spacing: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            switch glyph {
            case .dot(let radius):
                var y = spacing / 2
                while y < size.height {
                    var x = spacing / 2
                    while x < size.width {
                        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                        x += spacing
                    }
                    y += spacing
                }
            case .symbol(let text, let font):
                let resolved = context.resolve(Text(text).font(font).foregroundColor(color))
                var y = spacing / 2
                while y < size.height {
                    var x = spacing / 2
                    while x < size.width {
                        context.draw(resolved, at: CGPoint(x: x, y: y), anchor: .center)
                        x += spacing
                    }
                    y += spacing
                }
            }
        }
    }
}
