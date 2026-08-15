//
//  IconArtView.swift
//  Chur
//
//  The single way to render a badge, bank or partner icon.
//
//  Counterpart to CardArtView, and deliberately a separate type despite sharing
//  CardArtLoader underneath. Card art has one placeholder — a grey rectangle
//  that plainly reads as "no picture". Icon art has as many fallbacks as there
//  are call sites: a category emoji, an issuer name, a `storefront` symbol, or
//  nothing at all. Those are the right fallbacks and worth keeping, so this
//  view resolves the image and lets each caller decide what fills the space
//  when there isn't one.
//
//  The failure mode this exists to contain: an icon that silently falls back to
//  an emoji looks *intentional*, where a missing card image looks broken. The
//  eleven icon names that have no art at all had been that way indefinitely
//  before P1d, invisible to everyone. `SeedDataValidator` now reports them —
//  the view stays quiet on purpose, because a user-facing "missing icon" marker
//  would be worse than the emoji it replaced.
//

import SwiftUI

struct IconArtView<Fallback: View>: View {

    let imageName: String?
    let contentMode: ContentMode
    private let fallback: () -> Fallback

    @State private var remoteImage: UIImage?

    init(imageName: String?,
         contentMode: ContentMode = .fit,
         @ViewBuilder fallback: @escaping () -> Fallback) {
        self.imageName = imageName
        self.contentMode = contentMode
        self.fallback = fallback
    }

    var body: some View {
        Group {
            if let image = resolved {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                fallback()
            }
        }
        // Keyed on the index generation as well as the name, for the same reason
        // CardArtView is: a lookup that found nothing because the index had not
        // arrived yet has to run again once it has.
        .task(id: "\(imageName ?? "")#\(CardArtIndexState.shared.generation)") {
            guard let imageName, !imageName.isEmpty, resolved == nil else { return }
            remoteImage = await CardArtLoader.shared.image(for: imageName)
        }
    }

    /// Bundled asset first, so anything still in the catalog (UI art, and any
    /// icon ever re-bundled) stays instant and correct.
    private var resolved: UIImage? {
        guard let imageName, !imageName.isEmpty else { return nil }
        if let bundled = CardArtStore.bundledImage(named: imageName) { return bundled }
        if let remoteImage { return remoteImage }
        return CardArtLoader.shared.cached(imageName)
    }
}

// MARK: - No fallback

extension IconArtView where Fallback == EmptyView {

    /// For call sites that showed the icon or nothing — an issuer chip whose
    /// logo is optional, an alliance badge beside a partner name.
    init(imageName: String?, contentMode: ContentMode = .fit) {
        self.init(imageName: imageName, contentMode: contentMode) { EmptyView() }
    }
}
