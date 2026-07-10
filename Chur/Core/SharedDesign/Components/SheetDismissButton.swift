import SwiftUI

/// Reusable dismiss button for sheet/detail screens.
/// Positioned top-trailing with consistent padding.
///
/// Usage (inside a `ZStack(alignment: .topTrailing)`):
/// ```
/// SheetDismissButton { dismiss() }
/// SheetDismissButton(color: .churMediumGray) { dismiss() }
/// ```
struct SheetDismissButton: View {
    var color: Color = .churDarkGray
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.churBigTitle3())
                .symbolRenderingMode(.palette)
                .foregroundStyle(color, .white)
        }
        .padding(.top, 12)
        .padding(.trailing, 16)
    }
}
