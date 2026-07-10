//
//  NewsComponents.swift
//  Chur
//
//  Created by Pak Ho on 5/3/26.
//

import SwiftUI

// News Detail Wrapper (adds Toolbar)
struct NewsDetailPopup: View {
    let post: SanityPost
    var allPosts: [SanityPost] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Use a ZStack to float the close button over the immersive header
        ZStack(alignment: .topTrailing) {
            NewsDetailView(post: post, allPosts: allPosts)
            
            // Immersive Floating Close Button
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.15)) // Subtle dark circle for contrast
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "xmark")
                        .font(.churCaption())
                        .foregroundStyle(.white)
                }
            }
            .padding(.trailing, 20)
            .padding(.top, 20) // Positioned safely within the top olive area
        }
    }
}

// Standard News Row
struct NewsRowView: View {
    let post: SanityPost
    private var linkedIssuer: Issuer? {
        guard let id = post.issuerId else { return nil }
        return IssuerDatabase.byID[id]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(post.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                Text(post.formattedDate).font(.caption).foregroundStyle(.secondary)
                if let body = post.body?.first?.plainText {
                    Text(body).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let heroURL = post.postImage?.imageURL {
                AsyncImage(url: heroURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
                    } else { Color.churLightGray.frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10)) }
                }
            } else if let issuer = linkedIssuer {
                Image(issuer.logoImageName).resizable().scaledToFit().frame(width: 36, height: 36).padding(10)
                    .background(Color.churLightGray.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding().background(RoundedRectangle(cornerRadius: 12).fill(.white))
    }
}

struct PortableTextView: View {
    let blocks: [RawPortableText]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(blocks.indices, id: \.self) { index in
                if blocks[index]._type == "block" {
                    PortableTextBlockView(block: blocks[index], blocks: blocks)
                }
            }
        }
    }
}

struct PortableTextBlockView: View {
    let block: RawPortableText
    let blocks: [RawPortableText]
    
    var body: some View {
        let style = block.style ?? "normal"
        HStack(alignment: .top, spacing: 8) {
            if let listItem = block.listItem {
                let indent = CGFloat((block.level ?? 1) - 1) * 20
                Spacer().frame(width: indent)
                Text(listItem == "bullet" ? "•" : "\(getListNumber()).")
                    .font(.body).foregroundStyle(Color.churDarkGray).frame(width: 20, alignment: .leading)
            }
            FormattedTextView(children: block.children ?? [], markDefs: block.markDefs ?? [], style: style)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func getListNumber() -> Int {
        let currentIndex = blocks.firstIndex(where: { $0._key == block._key }) ?? 0
        return blocks.prefix(currentIndex).filter { $0.listItem == "number" && $0.level == block.level }.count + 1
    }
}

struct FormattedTextView: View {
    let children: [TextChild]; let markDefs: [MarkDef]; let style: String
    
    var body: some View {
        let attributedString = buildAttributedString()
        Group {
            switch style {
            case "h1", "h2", "h3": Text(attributedString).font(.title.bold())
            case "blockquote":
                HStack(spacing: 12) {
                    Rectangle().fill(Color.churOlive).frame(width: 4)
                    Text(attributedString).font(.body).italic().foregroundStyle(Color.churMediumGray)
                }
            default: Text(attributedString).font(.body).lineSpacing(4)
            }
        }.foregroundStyle(Color.churDarkGray)
    }
    
    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()
        for child in children {
            var attr = AttributedString(child.text ?? "")
            if let marks = child.marks {
                for mark in marks {
                    if mark == "strong" { attr.font = .body.bold() }
                    if mark == "em" { attr.font = .body.italic() }
                    if let def = markDefs.first(where: { $0._key == mark }), let url = URL(string: def.href ?? "") {
                        attr.link = url; attr.foregroundColor = Color.churOlive; attr.underlineStyle = .single
                    }
                }
            }
            result.append(attr)
        }
        return result
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize; var frames: [CGRect]
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var f: [CGRect] = []; var x: CGFloat = 0; var y: CGFloat = 0; var h: CGFloat = 0
            for subview in subviews {
                let s = subview.sizeThatFits(.unspecified)
                if x + s.width > maxWidth && x > 0 { x = 0; y += h + spacing; h = 0 }
                f.append(CGRect(x: x, y: y, width: s.width, height: s.height))
                h = max(h, s.height); x += s.width + spacing
            }
            self.frames = f; self.size = CGSize(width: maxWidth, height: y + h)
        }
    }
}

