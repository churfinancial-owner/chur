//
//  ChurMenuSheet.swift
//  Chur
//
//  The small bottom sheet that replaced `Menu` for action lists and filters.
//
//  It sizes itself. A detent has to be a number, and making every caller count
//  its own rows is a number that goes stale the first time someone adds an
//  option — so the content is measured and the detent follows it.
//

import SwiftUI

private struct ChurMenuHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ChurMenuSheet<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: () -> Content

    /// Seeded rather than 0: a detent of zero on the first layout pass makes the
    /// sheet animate up from nothing, which reads as a glitch.
    @State private var measured: CGFloat = 240

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let title {
                    Text(title.uppercased())
                        .font(.churMicroBold())
                        .kerning(1.2)
                        .foregroundStyle(Color.churMediumGray)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 10)
                }
                content()
            }
            .padding(.top, 18)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ChurMenuHeightKey.self, value: proxy.size.height)
                }
            )
        }
        // The sheet never wants to scroll at these sizes; the ScrollView is only
        // there so an unusually long list stays reachable on a small device.
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.churOffWhite)
        .onPreferenceChange(ChurMenuHeightKey.self) { measured = $0 }
        .presentationDetents([.height(min(measured, 560))])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}

/// One selectable line in a `ChurMenuSheet`.
///
/// **Dismisses itself.** "Closes after you pick something" is the behaviour
/// being bought here, and leaving it to each call site is how one of them ends
/// up not doing it.
struct ChurMenuRow<Trailing: View>: View {
    let title: String
    var systemImage: String? = nil
    var isSelected: Bool = false
    @ViewBuilder var trailing: () -> Trailing
    let action: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            action()
            dismiss()
        } label: {
            HStack(spacing: 14) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.churImageMedium())
                        .foregroundStyle(isSelected ? Color.churSageDeep : Color.churMediumGray)
                        .frame(width: 24)
                }

                Text(title)
                    .font(.churRowText())
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundStyle(isSelected ? Color.churSageDeep : Color.churDarkGray)

                Spacer(minLength: 8)
                trailing()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension ChurMenuRow where Trailing == EmptyView {
    init(title: String, systemImage: String? = nil, isSelected: Bool = false, action: @escaping () -> Void) {
        self.init(title: title, systemImage: systemImage, isSelected: isSelected,
                  trailing: { EmptyView() }, action: action)
    }
}

/// Section heading inside a `ChurMenuSheet`.
struct ChurMenuSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.churNanoBold())
            .kerning(1.0)
            .foregroundStyle(Color.churMediumGray)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }
}
