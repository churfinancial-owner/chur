import SwiftUI

/// Reusable pattern-image header banner for detail/popup screens.
///
struct PatternHeaderBanner<Icon: View>: View {
    var imageName: String = "HeaderPattern1"
    var bannerHeight: CGFloat = 100
    var iconSize: CGFloat = 72
    var iconPadding: CGFloat = 8
    var iconCornerRadius: CGFloat = 20
    var iconBackground: Color = Color(.churOffWhite)
    @ViewBuilder var icon: () -> Icon

    private var overlapOffset: CGFloat { (iconSize + iconPadding * 2) / 2 }

    var body: some View {
        VStack(spacing: 0) {
            // Pattern band — fills into the safe area
            Color.clear
                .frame(height: bannerHeight)
                .background(
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                )
                .clipped()
                .ignoresSafeArea(edges: .top)

            // Overlapping icon
            icon()
                .frame(width: iconSize, height: iconSize)
                .padding(iconPadding)
                .background(
                    RoundedRectangle(cornerRadius: iconCornerRadius)
                        .fill(iconBackground)
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                )
                .offset(y: -overlapOffset)
                .padding(.bottom, -overlapOffset)
        }
    }
}

/// Convenience initializer when no icon overlay is needed — just the banner.
extension PatternHeaderBanner where Icon == EmptyView {
    init(imageName: String = "HeaderPattern1", bannerHeight: CGFloat = 100) {
        self.imageName = imageName
        self.bannerHeight = bannerHeight
        self.iconSize = 0
        self.iconPadding = 0
        self.iconCornerRadius = 0
        self.iconBackground = .clear
        self.icon = { EmptyView() }
    }
}
