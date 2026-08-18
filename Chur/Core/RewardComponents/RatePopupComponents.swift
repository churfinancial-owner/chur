//
//  RatePopupComponents.swift
//  Chur
//
//  Shared UI components used by category and merchant rate popup sheets.
//

import SwiftUI

// MARK: - CardRateSummary Display Helpers

extension CardRateSummary {
    var formattedRateText: String {
        let r = rate
        if r == floor(r) { return "\(Int(r))x" }
        return String(format: (r * 10).truncatingRemainder(dividingBy: 1) == 0 ? "%.1fx" : "%.2fx", r)
    }

    var effectivePctText: String {
        let eff = effectiveCashBackRate
        guard eff > 0 else { return "–" }
        let pct = eff * 100
        if pct.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(pct))%" }
        if (pct * 10).truncatingRemainder(dividingBy: 1) == 0 { return String(format: "%.1f%%", pct) }
        return String(format: "%.2f%%", pct)
    }

    func preferredRateMode(showEffectiveRate: Bool) -> RatePill.DisplayMode {
        if showEffectiveRate {
            if effectiveCashBackRate == 0 { return .empty }
            return effectiveCashBackRate < 0 ? .effectiveNegative : .effectivePositive
        }
        return rate > 0 ? .points : .empty
    }

    func preferredRateText(showEffectiveRate: Bool) -> String {
        showEffectiveRate ? effectiveRateDisplayString : formattedRateText
    }
}

// MARK: - Sage Hero Header

/// Geometry for the sage hero treatment, shared by the merchant, category and
/// benefit sheets.
enum PopupHeroMetrics {
    /// White avatar circle. Much smaller than the 140pt tinted watermark it
    /// replaced — the mark is an object sitting on the hero rather than a tint
    /// washing through it, so it reads at a fraction of the size.
    static let avatar: CGFloat = 94
    /// Logo inside the circle, leaving a white ring around it.
    static let logo: CGFloat = 55
    static let avatarTrailing: CGFloat = 20
    static let avatarTop: CGFloat = 18

    /// Hero padding. Tight on top, deep at the bottom so the overlap card has
    /// sage to bite into — this is what keeps the header at ~2/3 height while
    /// still reading as a hero.
    static let topPadding: CGFloat = 28
    static let bottomPadding: CGFloat = 76
    static let horizontalPadding: CGFloat = 24

    /// How far the elevated layer is pulled up into the hero.
    static let overlap: CGFloat = 48

    /// Bottom corner radius of the sage itself.
    ///
    /// The bite needs *both* shapes curved. Rounding only the white card left
    /// the sage a flat horizontal band with a card sitting on it — the two
    /// surfaces read as a background and a foreground rather than as two
    /// organic shapes overlapping. Slightly larger than the card's radius so
    /// the sage reads as the outer form wrapping around it.
    static let bottomRadius: CGFloat = 28

    /// Trailing inset for hero text so it clears the avatar.
    static let contentInset: CGFloat = avatar + avatarTrailing + 8

    /// How far the sage is extended upward past the top of the hero.
    ///
    /// The hero scrolls; the ScrollView's own background does not. So a
    /// rubber-band pull at the top slid the sage down and revealed the
    /// off-white page behind it — the two surfaces visibly came apart, which
    /// reads as the header detaching from the sheet. Large enough to outrun any
    /// realistic overscroll; it costs nothing, being a solid fill with no
    /// layout effect.
    static let topBleed: CGFloat = 1000
}

/// The elevated layer: how every white card on a sage screen is built.
enum PopupCardMetrics {
    /// Internal gutter. One value, applied by the card container, which is why
    /// the content inside it carries no horizontal padding of its own — two
    /// gutters stacked is how a card ends up looking cramped and misaligned.
    static let gutter: CGFloat = 20
    /// Vertical rhythm between separate cards.
    static let stackSpacing: CGFloat = 16
    static let radius: CGFloat = 24
}

/// The sage hero: flat colour, text at the leading edge, a floating white
/// avatar top-trailing.
///
/// No `RepeatingPatternBackground` here, unlike the headers this replaces. The
/// sage carries the weight now, and the dot/glyph texture read as noise behind
/// it. `ToolSheetHeaderBanner`'s ten screens keep their pattern — they are a
/// different family and are not changing.
struct PopupHeroHeader<Content: View, Avatar: View>: View {
    /// Whether the avatar circle is drawn at all.
    ///
    /// Not every screen has a mark to show — 81 of 276 benefits name no
    /// partner — and an empty white circle reads as a failed image rather than
    /// as "there is nothing here". A Bool rather than an optional closure
    /// because a generic view cannot ask whether its content is empty.
    var showsAvatar: Bool = true
    @ViewBuilder var content: () -> Content
    @ViewBuilder var avatar: () -> Avatar

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PopupHeroMetrics.horizontalPadding)
            .padding(.top, PopupHeroMetrics.topPadding)
            .padding(.bottom, PopupHeroMetrics.bottomPadding)
            // Shaped background rather than a clipShape on the whole view, so
            // the avatar's shadow is not trimmed at the hero's edges.
            //
            // The negative top padding stretches the fill up past the hero and
            // out through the safe area. Background content is not clipped to
            // its host, so this is free: the shape keeps its rounded bottom and
            // simply has more of itself above, which is what an overscroll
            // reveals instead of the page colour.
            .background(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: PopupHeroMetrics.bottomRadius,
                    bottomTrailingRadius: PopupHeroMetrics.bottomRadius,
                    style: .continuous
                )
                .fill(Color.churSage)
                .padding(.top, -PopupHeroMetrics.topBleed)
            )
            .overlay(alignment: .topTrailing) {
                if showsAvatar {
                    avatar()
                        .frame(width: PopupHeroMetrics.logo, height: PopupHeroMetrics.logo)
                        .frame(width: PopupHeroMetrics.avatar, height: PopupHeroMetrics.avatar)
                        .background(Color.white, in: Circle())
                        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
                        .padding(.trailing, PopupHeroMetrics.avatarTrailing)
                        .padding(.top, PopupHeroMetrics.avatarTop)
                        .allowsHitTesting(false)
                }
            }
    }
}

extension PopupHeroHeader where Avatar == EmptyView {

    /// For a hero with no mark to show — the period management sheet, or a
    /// benefit whose partner has no artwork. The avatar closure is never
    /// evaluated, so `EmptyView` is safe here in a way it is not inside
    /// `IconArtView`.
    init(@ViewBuilder content: @escaping () -> Content) {
        self.init(showsAvatar: false, content: content, avatar: { EmptyView() })
    }
}

extension View {

    /// Diffused ambient shadow — the card floats a few millimetres above the
    /// surface rather than casting a hard edge.
    ///
    /// `shadow-[0_8px_30px_rgba(0,0,0,0.04)]` in CSS terms. **SwiftUI's
    /// `radius` is roughly half a CSS blur**, so a 30px blur is `radius: 15`,
    /// not 30 — getting that wrong is how a soft shadow turns into a smudge.
    func ambientCardShadow() -> some View {
        shadow(color: .black.opacity(0.04), radius: 15, y: 8)
    }

    /// Pulls the elevated layer up so it bites into the hero above it.
    ///
    /// Applied to the card itself rather than to a slab wrapping the whole
    /// page: the first *card* is what overlaps the sage in the reference, so
    /// its rounded corners and its shadow both land on colour. Wrapping
    /// everything in one off-white sheet — which is what this was first built
    /// as — puts a flat panel between the sage and the cards and loses the
    /// contrast the effect is made of.
    func popupHeroOverlap() -> some View {
        padding(.top, -PopupHeroMetrics.overlap)
    }
}

extension View {

    /// Hero title: the anchor the eye lands on when the popup opens.
    ///
    /// Near-black rather than `churDarkGray`, which is the body colour and does
    /// not carry enough weight against sage to anchor the screen. That colour
    /// now belongs to the subtitle underneath, one clear step down.
    ///
    /// **The trailing inset is not baked in.** A hero with no avatar has the
    /// full width to spend on the title, and hard-coding the inset here cost
    /// the period management sheet ~120pt of title for a circle it never draws.
    /// Add `.popupHeroInset()` at the sites that do have a mark.
    func popupHeroTitle(lineLimit: Int = 2) -> some View {
        self
            .font(.churBigTitle3())
            .foregroundStyle(Color.churBlack)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.8)
    }

    /// Hero subtitle and pill rows — same inset, no type opinion.
    func popupHeroInset() -> some View {
        padding(.trailing, PopupHeroMetrics.contentInset)
    }
}

// MARK: - Best Card Tile Content

struct PopupBestCardContent: View {
    let summary: CardRateSummary
    let card: CreditCard?
    let showFormula: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CardThumbnailView(card: card, width: 84, height: 54)
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.name)
                        .font(.churHeadline())
                        .foregroundStyle(Color.churDarkGray)
                        .lineLimit(1)
                    Text(card.map { IssuerDatabase.byName[$0.issuer]?.shortName ?? $0.issuer } ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.churMediumGray)
                }
                Spacer()
            }
            .padding(.bottom, 14)

            BestCardStatStrip(
                rateText: summary.formattedRateText,
                effectivePctText: summary.effectivePctText,
                isEffectiveNegative: summary.effectiveCashBackRate < 0
            )

            if showFormula {
                RateFormulaRow(
                    formattedRate: summary.formattedRateText,
                    pointValueText: summary.pointValueDisplayString,
                    effectiveRateText: summary.effectiveRateDisplayString,
                    isNegative: summary.effectiveCashBackRate < 0
                )
                .padding(.top, 12)
            }
        }
    }
}

// MARK: - Comparison Row

struct PopupComparisonRow: View {
    let summary: CardRateSummary
    let card: CreditCard?
    let showFormula: Bool

    @Environment(\.rewardDisplay) private var rewardDisplay

    var body: some View {
        HStack(spacing: 12) {
            CardThumbnailView(card: card, width: 60, height: 38)
                .shadow(color: .black.opacity(0.08), radius: 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.name)
                    .font(.churRowText())
                    .foregroundStyle(Color.churDarkGray)
                    .lineLimit(1)
                Text(card.map { IssuerDatabase.byName[$0.issuer]?.shortName ?? $0.issuer } ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.churMediumGray)
                    .lineLimit(1)
            }
            Spacer()
            if showFormula {
                HStack(spacing: 6) {
                    RatePill(text: summary.formattedRateText, displayMode: .points, size: .medium)
                    RatePill(
                        text: summary.effectiveRateDisplayString,
                        displayMode: summary.effectiveCashBackRate < 0 ? .effectiveNegative : .effectivePositive,
                        size: .medium
                    )
                }
            } else {
                RatePill(
                    text: summary.preferredRateText(showEffectiveRate: rewardDisplay.showEffectiveRate),
                    displayMode: summary.preferredRateMode(showEffectiveRate: rewardDisplay.showEffectiveRate),
                    size: .medium
                )
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Section Card

/// The elevated layer: one white card on a sage screen.
///
/// Every section on these sheets is one of these, with or without the corner
/// tab. Replaces `RateTileContainer`, which was the same thing but always
/// tabbed and only ever used by the rate stack.
struct PopupSectionCard<Content: View>: View {
    /// Corner tab label. Nil draws a plain card.
    var tabTitle: String? = nil
    var tabColor: Color = .churGold
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let tabTitle {
                // A tab anchored in the corner, square on the outside and
                // rounded only where it meets the card's interior. The card's
                // own clip trims its top-leading corner to match the card
                // radius, which is why it sits flush rather than in the gutter.
                HStack {
                    Text(tabTitle)
                        .font(.churBadgeBold())
                        .kerning(1.2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(tabColor)
                        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 8))
                    Spacer()
                }
            }

            // The gutter is on the content, not the whole card — the tab has to
            // reach the corner. Content inside carries none of its own; see
            // PopupCardMetrics.gutter.
            content()
                .padding(PopupCardMetrics.gutter)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.churTileWhiteBg)
        .clipShape(RoundedRectangle(cornerRadius: PopupCardMetrics.radius, style: .continuous))
        .ambientCardShadow()
    }
}

// MARK: - Best Card Stat Strip

struct BestCardStatStrip: View {
    let rateText: String
    let effectivePctText: String
    var isEffectiveNegative: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            statCell(value: rateText, label: AppLocale.string("CARD RATE"), mode: .points)
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(width: 1)
                .padding(.vertical, 8)
            statCell(value: effectivePctText, label: AppLocale.string("EFFECTIVE RATE"), mode: isEffectiveNegative ? .effectiveNegative : .effectivePositive)
        }
        .background(Color.churOffWhite)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statCell(value: String, label: String, mode: RatePill.DisplayMode) -> some View {
        VStack(spacing: 5) {
            RatePill(text: value, displayMode: mode, size: .hero, showBackground: false)
            Text(label)
                .font(.churNanoBold())
                .kerning(0.8)
                .foregroundStyle(Color.churMediumGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - Rate Formula Row

struct RateFormulaRow: View {
    let formattedRate: String
    let pointValueText: String
    let effectiveRateText: String
    let isNegative: Bool

    var body: some View {
        HStack(spacing: 0) {
            rateColumn(label: AppLocale.string("Card Rate"), text: formattedRate, mode: .points)
            operatorLabel("×")
            rateColumn(label: AppLocale.string("Point Value"), text: pointValueText, mode: .programpointvalue)
            operatorLabel("=")
            rateColumn(label: AppLocale.string("Effective Rate"), text: effectiveRateText, mode: isNegative ? .effectiveNegative : .effectivePositive)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func rateColumn(label: String, text: String, mode: RatePill.DisplayMode) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.churBadgeMedium()).foregroundStyle(Color.churDarkGray)
            RatePill(text: text, displayMode: mode, size: .medium)
        }
    }

    private func operatorLabel(_ symbol: String) -> some View {
        Text(symbol)
            .font(.churFootnoteBold())
            .foregroundStyle(Color.churMediumGray)
            .padding(.horizontal, 6)
            .padding(.top, 14)
    }
}

// MARK: - Shared Recommendation Stack
//
// Used by both ParentCategoryParallaxSheet and MerchantDetailSheet to render
// the "BEST CARD TO USE" + "OTHER GREAT OPTIONS" sections.
// Owns its own isExpanded state so callers only need to pass data + showFormula.

struct RecommendationStackView: View {
    let bestCardSummary: CardRateSummary?
    let otherCardRates: [CardRateSummary]
    let cards: [CreditCard]
    let showFormula: Bool

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: PopupCardMetrics.stackSpacing) {
            if let best = bestCardSummary {
                PopupSectionCard(tabTitle: AppLocale.string("BEST CARD TO USE"), tabColor: .churGold) {
                    PopupBestCardContent(
                        summary: best,
                        card: cards.first(where: { $0.name == best.name }),
                        showFormula: showFormula
                    )
                }
                if !otherCardRates.isEmpty {
                    PopupSectionCard(tabTitle: AppLocale.string("OTHER GREAT OPTIONS"), tabColor: .churMediumGray) {
                        comparisonContent
                    }
                }
            } else {
                EmptyStatePlaceholder(icon: "creditcard.trianglebadge.exclamationmark", title: AppLocale.string("No matching cards"), subtitle: AppLocale.string("None of your cards earn rewards in this category."))
            }
        }
        .padding(.horizontal, 16)
    }

    private var comparisonContent: some View {
        Group {
            if isExpanded {
                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        ForEach(otherCardRates.prefix(5), id: \.name) { comparisonRow(for: $0) }
                    }
                    RateToggleButton(text: AppLocale.string("Show Less"), icon: "chevron.up") {
                        withAnimation(.spring(response: 0.3)) { isExpanded = false }
                    }
                }
            } else {
                Button { withAnimation(.spring(response: 0.3)) { isExpanded = true } } label: {
                    HStack {
                        HStack(spacing: 8) {
                            ForEach(otherCardRates.prefix(5), id: \.name) { summary in
                                CardThumbnailView(card: cards.first(where: { $0.name == summary.name }), width: 36, height: 22)
                                    .shadow(color: .black.opacity(0.1), radius: 2)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.churMediumGray)
                    }
                    .padding(.vertical, 12)
                }
            }
        }.transition(.opacity)
    }

    private func comparisonRow(for summary: CardRateSummary) -> some View {
        PopupComparisonRow(
            summary: summary,
            card: cards.first(where: { $0.name == summary.name }),
            showFormula: showFormula
        )
    }
}

// MARK: - Toggle Button

struct RateToggleButton: View {
    let text: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack { Text(text); Image(systemName: icon) }
                .font(.churSmallBold())
                .foregroundStyle(Color.churMediumGray)
                .padding(.bottom, 16)
        }
    }
}

// MARK: - Header Capsule Bubble

struct HeaderCapsuleBubble: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.churBadge())
            Text(text)
                .font(.churMicroBold())
        }
        .foregroundStyle(Color.churDarkGray)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.churOlive.opacity(0.45))
        .clipShape(Capsule())
    }
}

//  MARK: - MerchantPopup_Components

import SwiftUI

struct CardThumbnailView: View {
    let card: CreditCard?
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        if let card {
            CardArtView(imageName: card.imageName, contentMode: .fit) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.cardColor(for: card.issuer))
                    .overlay {
                        Text(card.issuer.prefix(2).uppercased())
                            .font(.system(size: width > 70 ? 22 : 14, weight: .black))
                            .foregroundStyle(.white)
                    }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Merchant Icon View

/// Displays a merchant's brand icon if available, otherwise falls back to the category icon/emoji.
/// Uses `.scaledToFit()` so wide wordmark logos (Amazon, Costco, etc.) are fully visible.
struct MerchantIconView: View {
    let iconName: String?
    let category: SpendingCategory?

    /// Size of the emoji shown when there is no icon.
    ///
    /// A parameter rather than a constant because this view is used at three
    /// very different sizes — a 56×36 search row, an 82pt tile, and an 80×80
    /// popup watermark — while the fallback was fixed at the watermark's 80pt.
    /// An image `.scaledToFit()`s into whatever frame the caller gives it; a
    /// `Text` does not, so the size has to travel with the call site.
    ///
    /// This was latent until P1d. Merchant icons shipped in the bundle, so the
    /// fallback almost never rendered; now it also covers the gap before an icon
    /// downloads, and any merchant whose art is missing entirely.
    var emojiFont: Font = .churHeadline()

    var body: some View {
        IconArtView(imageName: iconName) {
            unavailable
        }
    }

    /// What fills the space when the merchant has no icon, or it hasn't
    /// downloaded yet.
    @ViewBuilder
    private var unavailable: some View {
        if let category {
            CategoryIconView(category: category, font: emojiFont)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Image(systemName: "storefront")
                .font(.churBigTitle4())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
