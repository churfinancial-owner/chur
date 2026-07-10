import SwiftUI

// MARK: - Postcard Share Sheet

struct PostcardShareSheet: View {
    let user: User
    let cards: [CreditCard]

    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: URL? = nil

    private var orderedCards: [CreditCard] {
        let order = user.cardDisplayOrder
        let cardMap = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        // cardDisplayOrder stores primary at the end (CardOrderSheet displays it reversed),
        // so reverse here to match the user-visible list order (primary first).
        let ordered = order.reversed().compactMap { cardMap[$0] }
        let remaining = cards.filter { !order.contains($0.id) }
        return ordered + remaining
    }

    private var postcardContent: PostcardView {
        PostcardView(
            firstName: user.firstName,
            cardCount: cards.count,
            profilePhotoData: user.profilePhotoData,
            profileEmoji: user.profileEmoji,
            cardInfos: orderedCards.map { (
                imageName: $0.imageName,
                color: Color.cardColor(for: $0.issuer),
                issuer: $0.issuer
            )}
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                postcardContent
                    .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 10)
                    .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 10) {
                    if let url = shareURL {
                        ShareLink(
                            item: url,
                            preview: SharePreview("My Chur Wallet")
                        ) {
                            Label("Share Postcard", systemImage: "square.and.arrow.up")
                                .font(.churHeadline())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.churOlive)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    } else {
                        HStack(spacing: 10) {
                            ProgressView().tint(Color.churOlive)
                            Text("Preparing postcard…")
                                .font(.churCaptionRegular())
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                    }

                    Text("Your wallet, your story.")
                        .font(.churCaptionRegular())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Your Postcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.churRowText())
                        .fontWeight(.bold)
                        .foregroundStyle(Color.churOlive)
                }
            }
        }
        .task {
            shareURL = await renderToFile()
        }
    }

    @MainActor
    private func renderToFile() async -> URL? {
        let renderer = ImageRenderer(content: postcardContent)
        renderer.scale = 3.0
        guard let image = renderer.uiImage,
              let data = image.jpegData(compressionQuality: 0.92) else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("chur-postcard.jpg")

        try? data.write(to: url)
        return url
    }
}

import SwiftUI

// MARK: - Postcard View (V1 Fan - Rearranged)

struct PostcardView: View {
    let firstName: String
    let cardCount: Int
    let profilePhotoData: Data?
    let profileEmoji: String
    let cardInfos: [(imageName: String, color: Color, issuer: String)]

    private let size: CGFloat = 360

    // Design palette
    private let oliveDark   = Color(red: 67/255,  green: 67/255,  blue: 40/255)
    private let olive      = Color(red: 92/255,  green: 90/255,  blue: 51/255)
    private let oliveLight = Color(red: 212/255, green: 210/255, blue: 155/255)
    private let beige      = Color(red: 245/255, green: 239/255, blue: 220/255)
    private let offWhite   = Color(red: 250/255, green: 248/255, blue: 243/255)

    private var visibleCards: [(imageName: String, color: Color, issuer: String)] {
        Array(cardInfos.prefix(6))
    }

    private var cardW: CGFloat {
        cardInfos.count <= 3 ? size * 0.62 : size * 0.55
    }

    private var cardH: CGFloat { cardW * 0.63 }

    private var totalSpread: Double {
        min(60, Double(visibleCards.count) * 10)
    }

    var body: some View {
        ZStack {
            // ── Background ─────────────────────────────────
            LinearGradient(
                stops: [
                    .init(color: oliveLight, location: 0),
                    .init(color: beige,      location: 0.6),
                    .init(color: offWhite,   location: 1)
                ],
                startPoint: UnitPoint(x: 0.15, y: 0),
                endPoint:   UnitPoint(x: 0.85, y: 1)
            )

            // Paper texture radial overlays
            RadialGradient(
                colors: [.white.opacity(0.4), .clear],
                center: UnitPoint(x: 0.3, y: 0.2),
                startRadius: 0,
                endRadius: size * 0.4
            )
            RadialGradient(
                colors: [olive.opacity(0.08), .clear],
                center: UnitPoint(x: 0.7, y: 0.8),
                startRadius: 0,
                endRadius: size * 0.5
            )

            // ── Header (Logo only, Top Right is Empty) ─────
            VStack {
                HStack {
                    Text("chur")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(olive)
                        .tracking(0.6)
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                Spacer()
            }

            // ── Fanned Cards ────────────────────────────────
            ZStack {
                ForEach(Array(visibleCards.enumerated()), id: \.offset) { i, card in
                    let (rot, dx, dy) = fanTransform(index: i, count: visibleCards.count)
                    fanCard(card)
                        .offset(x: dx, y: dy - 30)
                        .rotationEffect(.degrees(rot))
                        .zIndex(Double(visibleCards.count - 1 - i))
                }
            }

            // ── Footer (Rearranged) ──────────────────────────
            VStack {
                Spacer()
                HStack(alignment: .bottom) { // Aligned to bottom
                    
                    // NEW: Combined (Icon) Name | Wallet (Lower Left)
                    HStack(spacing: 8) {
                        avatarView
                        
                        HStack(spacing: 6) {
                            Text(firstName)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(oliveDark)
                                .tracking(-0.1)
                            
                            // Visual Separator pipe
                            Text("|")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(olive.opacity(0.4))

                            Text("WALLET")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(olive.opacity(0.7))
                                .tracking(1.5)
                        }
                    }
                    .padding(.bottom, 2) // Small baseline lift

                    Spacer()
                    
                    // Cards Count (Properly Aligned Lower Right)
                    VStack(alignment: .trailing, spacing: 0) { // Spacing 0 keeps text close
                        Text("\(cardCount)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(oliveDark)
                            .lineLimit(1)
                        
                        Text(cardCount == 1 ? "CARD" : "CARDS")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(olive.opacity(0.6))
                            .tracking(1.2)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 22)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.45), .clear, .white.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    // MARK: - Fan Math

    private func fanTransform(index i: Int, count n: Int) -> (rotation: Double, offsetX: CGFloat, offsetY: CGFloat) {
        guard n > 1 else { return (0, 0, 0) }
        let frac   = Double(i) / Double(n - 1)
        let rot    = (frac - 0.5) * totalSpread
        let dx     = CGFloat((frac - 0.5) * Double(cardW) * 0.5)
        let dy     = CGFloat(abs(frac - 0.5) * 20)
        return (rot, dx, dy)
    }

    // MARK: - Fan Card

    @ViewBuilder
    private func fanCard(_ card: (imageName: String, color: Color, issuer: String)) -> some View {
        Group {
            if let uiImage = UIImage(named: card.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .antialiased(true)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardW, height: cardH)
                    .clipped()
            } else {
                ZStack(alignment: .topLeading) {
                    // Card gradient
                    LinearGradient(
                        colors: [card.color, card.color.opacity(0.72)],
                        startPoint: UnitPoint(x: 0.1, y: 0.1),
                        endPoint:   UnitPoint(x: 0.9, y: 0.9)
                    )

                    // Shine
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.14), location: 0),
                            .init(color: .clear,               location: 0.4),
                            .init(color: .clear,               location: 0.6),
                            .init(color: .white.opacity(0.06), location: 1)
                        ],
                        startPoint: UnitPoint(x: 0.1, y: 0.1),
                        endPoint:   UnitPoint(x: 0.9, y: 0.9)
                    )

                    // Decorative circles
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                        .frame(width: cardW * 0.64, height: cardW * 0.64)
                        .offset(x: cardW * 0.55, y: -cardW * 0.18)
                    Circle()
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                        .frame(width: cardW * 0.43, height: cardW * 0.43)
                        .offset(x: cardW * 0.55, y: -cardW * 0.18)

                    // Card labels
                    VStack(alignment: .leading) {
                        HStack {
                            Text(card.issuer)
                                .font(.system(size: cardW * 0.045, weight: .heavy))
                                .foregroundStyle(.white)
                                .tracking(1.2)
                            Spacer()
                            // EMV chip
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 194/255, green: 160/255, blue: 99/255),
                                            Color(red: 155/255, green: 124/255, blue: 70/255)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: cardW * 0.11, height: cardW * 0.085)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(.white.opacity(0.3), lineWidth: 0.5)
                                )
                        }
                        Spacer()
                        Text(card.issuer)
                            .font(.system(size: cardW * 0.05, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    .padding(cardW * 0.06)
                    .frame(width: cardW, height: cardH)
                }
                .frame(width: cardW, height: cardH)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cardW * 0.06))
        .overlay(
            RoundedRectangle(cornerRadius: cardW * 0.06)
                .stroke(.white.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 14)
        .shadow(color: .black.opacity(0.10), radius: 6,   x: 0, y: 2)
    }

    // MARK: - Avatar

    private var avatarView: some View {
        let d: CGFloat = 34
        return ZStack {
            if let data = profilePhotoData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: d, height: d)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 194/255, green: 160/255, blue: 99/255),
                                Color(red: 150/255, green: 120/255, blue: 70/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: d, height: d)

                Text(profileEmoji.isEmpty ? String(firstName.prefix(2)).uppercased() : profileEmoji)
                    .font(.system(size: profileEmoji.isEmpty ? 12 : 16, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: d, height: d)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(.white.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
    }
}
