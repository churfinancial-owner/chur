import SwiftUI

/// Circular 32-pt olive-ring icon — stroked outline instead of a filled disc,
/// so the icon doesn't pop as hard against card backgrounds as OliveIconButton does.
struct OliveRingIcon: View {
    let icon: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.churOlive.opacity(0.4), lineWidth: 1.5)
                .frame(width: 32, height: 32)
            Image(systemName: icon)
                .font(.churImageMedium())
                .foregroundStyle(Color.churOlive)
        }
    }
}

/// Button wrapper around OliveRingIcon for simple tap actions.
/// For a Menu label, use OliveRingIcon directly.
struct OliveRingIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            OliveRingIcon(icon: icon)
        }
    }
}
