//
//  CardArtView.swift
//  Chur
//
//  The single way to render a card image.
//
//  Every call site previously did its own `UIImage(named:)` lookup, which meant
//  19 slightly different behaviours and several that rendered nothing at all
//  when the asset was missing. Card art now resolves through one place: bundled
//  asset, then cache, then CDN, then a placeholder.
//
//  Callers keep their own `.frame`, `.clipShape` and `.shadow` — this view only
//  decides *what* fills the space, never how big it is.
//
//  The placeholder is overridable, like AsyncImage's. Two card rows already had
//  issuer-tinted fallbacks showing the issuer name, which are better than a grey
//  rectangle and worth keeping.
//

import SwiftUI

struct CardArtView<Placeholder: View>: View {

    let imageName: String
    let contentMode: ContentMode
    private let placeholder: () -> Placeholder

    @State private var remoteImage: UIImage?

    init(imageName: String,
         contentMode: ContentMode = .fill,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.imageName = imageName
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = resolved {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: imageName) {
            // Only reached when neither the bundle nor the caches have it —
            // the common path renders synchronously below.
            guard resolved == nil else { return }
            remoteImage = await CardArtLoader.shared.image(for: imageName)
        }
    }

    /// Bundled asset first: while art still ships in the binary it is instant
    /// and always correct. Once it stops shipping, this returns nil and the
    /// caches take over.
    private var resolved: UIImage? {
        if let bundled = UIImage(named: imageName) { return bundled }
        if let remoteImage { return remoteImage }
        return CardArtLoader.shared.cached(imageName)
    }
}

// MARK: - Default placeholder

extension CardArtView where Placeholder == CardArtPlaceholder {

    init(imageName: String,
         contentMode: ContentMode = .fill,
         placeholderCornerRadius: CGFloat = 8) {
        self.init(imageName: imageName, contentMode: contentMode) {
            CardArtPlaceholder(cornerRadius: placeholderCornerRadius)
        }
    }
}

/// Neutral grey card shape — deliberately quiet, since it appears both while
/// art is downloading and permanently for the cards that have none.
struct CardArtPlaceholder: View {

    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.churLightGray)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.churMediumGray.opacity(0.25), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}
