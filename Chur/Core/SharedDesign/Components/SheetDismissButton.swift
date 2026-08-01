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
            Text("✕")
                .font(.churFootnote())
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.7))
                .clipShape(Circle())
        }
        .padding(.top, 12)
        .padding(.trailing, 16)
    }
}
