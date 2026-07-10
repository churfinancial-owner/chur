import SwiftUI

// MARK: - Your Support Section

struct YourSupportSection: View {
    let user: User
    let cards: [CreditCard]

    @State private var showingPostcard = false
    @Environment(\.openURL) private var openURL

    private let coffeeURL = URL(string: "https://buymeacoffee.com/pakho")!

    var body: some View {
        VStack(spacing: 0) {
            sharePostcardRow
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            Divider()
                .padding(.leading, 54)

            coffeeRow
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .background(Color.churOffWhite)
        .sheet(isPresented: $showingPostcard) {
            PostcardShareSheet(user: user, cards: cards)
        }
    }

    // MARK: - Share Postcard Row

    private var sharePostcardRow: some View {
        Button { showingPostcard = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.churOlive)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Share your wallet")
                        .font(.churHeadline())
                        .foregroundStyle(Color.churDarkGray)
                    Text("Create a postcard of your card collection")
                        .font(.churCaptionRegular())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.churMediumGray)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Coffee Row

    private var coffeeRow: some View {
        Button { openURL(coffeeURL) } label: {
            HStack(spacing: 14) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.churGold)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Buy me a coffee")
                        .font(.churHeadline())
                        .foregroundStyle(Color.churDarkGray)
                    Text("Support the developer ☕")
                        .font(.churCaptionRegular())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(Color.churMediumGray)
            }
        }
        .buttonStyle(.plain)
    }
}

