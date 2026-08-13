//
//  CardArtView.swift
//  Chur
//
//  The single way to render a card image.
//
//  Every call site previously did its own `UIImage(named:)` lookup, which meant
//  18 slightly different behaviours and two that rendered nothing at all when
//  the asset was missing. Card art now resolves through one place: bundled
//  asset, then cache, then CDN, then a neutral placeholder.
//
//  Callers keep their own `.frame`, `.clipShape` and `.shadow` — this view only
//  decides *what* fills the space, never how big it is.
//

import SwiftUI

struct CardArtView: View {

    let imageName: String

    /// Corner radius for the placeholder only. The image itself is clipped by
    /// the caller, so this just keeps the grey rectangle from looking square
    /// inside a rounded frame.
    var placeholderCornerRadius: CGFloat = 8

    @State private var remoteImage: UIImage?

    var body: some View {
        Group {
            if let image = resolved {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .task(id: imageName) {
            // Only reached when neither the bundle nor the caches have it —
            // the common path renders synchronously above.
            guard resolved == nil else { return }
            remoteImage = await CardArtLoader.shared.image(for: imageName)
        }
    }

    /// Bundled asset first: while art still ships in the binary it is instant
    /// and always correct. Once it stops shipping, this simply returns nil and
    /// the cache takes over.
    private var resolved: UIImage? {
        if let bundled = UIImage(named: imageName) { return bundled }
        if let remoteImage { return remoteImage }
        return CardArtLoader.shared.cached(imageName)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: placeholderCornerRadius)
            .fill(Color.churLightGray)
            .overlay(
                RoundedRectangle(cornerRadius: placeholderCornerRadius)
                    .strokeBorder(Color.churMediumGray.opacity(0.25), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}
