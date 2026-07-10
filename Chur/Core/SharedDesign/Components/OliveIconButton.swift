import SwiftUI

/// Circular 32-pt olive-tinted icon button used in header toolbars across the app.
struct OliveIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.churOliveLight)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.churImageMedium())
                    .foregroundStyle(.churDarkOlive)
            }
        }
    }
}
