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

// MARK: - Popup Header Watermark

struct PopupHeaderWatermark<Content: View>: View {
    let tint: Color
    // Plain stored closure: both initialisers below carry the @ViewBuilder,
    // and the memberwise init this attribute would have shaped is gone.
    let content: () -> Content

    /// The original entry point: a merchant or category popup tints its circle
    /// by category.
    init(categoryID: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(tint: Color.categoryBadgeTint(for: categoryID), content: content)
    }

    /// For headers that have no category to tint by.
    ///
    /// The benefit detail sheet is the case this exists for. Its nearest field
    /// is `displayGroup`, and passing that through `categoryBadgeTint` lands
    /// badly: only the exact string `travel` matches a case, so 67 benefits
    /// would go travel-coloured while the larger `lifestyle_travel` group fell
    /// through to the default. One tint reads as deliberate; two thirds of a
    /// tint reads as a bug.
    init(tint: Color, @ViewBuilder content: @escaping () -> Content) {
        self.tint = tint
        self.content = content
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint)
                .frame(width: PopupHeaderMetrics.diameter, height: PopupHeaderMetrics.diameter)
            content()
        }
        .offset(x: PopupHeaderMetrics.overhang, y: PopupHeaderMetrics.verticalOffset)
        .allowsHitTesting(false)
    }
}

/// Geometry shared by the watermark and the headers that have to work around it.
///
/// A separate non-generic type on purpose: `PopupHeaderWatermark` is generic
/// over its content, and Swift does not allow static stored properties there.
enum PopupHeaderMetrics {
    static let diameter: CGFloat = 140
    /// How far the circle is pushed past the header's trailing edge.
    static let overhang: CGFloat = 30
    static let verticalOffset: CGFloat = -16

    /// Width the watermark actually covers inside the header, and therefore how
    /// far header text must be inset to clear it.
    ///
    /// Derived rather than written down: this was the literal `110` in two
    /// popups and was simply missing from the benefit sheet, where the title
    /// ran under the logo. A number repeated at every call site drifts the
    /// first time the circle is resized.
    static let contentInset: CGFloat = diameter - overhang
}

// MARK: - Sage Hero Header

/// Geometry for the sage hero treatment. Separate from `PopupHeaderMetrics`,
/// which describes the older tinted-circle watermark that the category and
/// benefit sheets still use.
enum PopupHeroMetrics {
    /// White avatar circle. Much smaller than the 140pt watermark it replaces —
    /// the mark is now an object sitting on the hero rather than a tint washing
    /// through it, so it reads at a fraction of the size.
    static let avatar: CGFloat = 72
    /// Logo inside the circle, leaving a white ring around it.
    static let logo: CGFloat = 42
    static let avatarTrailing: CGFloat = 20
    static let avatarTop: CGFloat = 18

    /// Hero padding. Tight on top, deep at the bottom so the overlap card has
    /// sage to bite into — this is what keeps the header at ~2/3 height while
    /// still reading as a hero.
    static let topPadding: CGFloat = 28
    static let bottomPadding: CGFloat = 76
    static let horizontalPadding: CGFloat = 24

    /// How far the content card is pulled up over the hero.
    static let overlap: CGFloat = 52
    static let cardRadius: CGFloat = 26

    /// Trailing inset for hero text so it clears the avatar.
    static let contentInset: CGFloat = avatar + avatarTrailing + 8
}

/// The sage hero: flat colour, text at the leading edge, a floating white
/// avatar top-trailing.
///
/// No `RepeatingPatternBackground` here, unlike the headers this replaces. The
/// sage carries the weight now, and the dot/glyph texture read as noise behind
/// it. `ToolSheetHeaderBanner`'s ten screens keep their pattern — they are a
/// different family and are not changing.
struct PopupHeroHeader<Content: View, Avatar: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var avatar: () -> Avatar

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PopupHeroMetrics.horizontalPadding)
            .padding(.top, PopupHeroMetrics.topPadding)
            .padding(.bottom, PopupHeroMetrics.bottomPadding)
            .background(Color.churSage)
            .overlay(alignment: .topTrailing) {
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

/// The white slab that bites into the hero above it.
///
/// The negative padding is on this view rather than a spacer above it so the
/// shadow falls on the sage instead of on a gap.
struct PopupOverlapCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .background(Color.churOffWhite)
            .clipShape(
                .rect(topLeadingRadius: PopupHeroMetrics.cardRadius,
                      topTrailingRadius: PopupHeroMetrics.cardRadius)
            )
            .shadow(color: .black.opacity(0.07), radius: 16, y: -4)
            .padding(.top, -PopupHeroMetrics.overlap)
    }
}

extension View {

    /// Hero title: the anchor the eye lands on when the popup opens.
    func popupHeroTitle() -> some View {
        self
            .font(.churBigTitle3())
            .foregroundStyle(Color.churDarkGray)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.trailing, PopupHeroMetrics.contentInset)
    }

    /// Hero subtitle and pill rows — same inset, no type opinion.
    func popupHeroInset() -> some View {
        padding(.trailing, PopupHeroMetrics.contentInset)
    }
}

// MARK: - Popup Header Title

extension View {

    /// The title treatment shared by every header carrying a
    /// `PopupHeaderWatermark`: sized, capped at two lines, allowed to shrink a
    /// little, and inset clear of the watermark.
    ///
    /// The three headers had drifted — `minimumScaleFactor` was 0.75 in
    /// MapMerchantPopup, 0.8 in ParentCategoryPopup and absent in the benefit
    /// sheet, which also had no inset at all. Settled at 0.8 here so there is
    /// one answer rather than three.
    func popupHeaderTitle() -> some View {
        self
            .font(.churBigTitle3())
            .foregroundStyle(Color.churDarkGray)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.trailing, PopupHeaderMetrics.contentInset)
    }

    /// For the non-title rows that share the watermark's band — a pill row or
    /// capsule bubble above the title.
    func popupHeaderInset() -> some View {
        padding(.trailing, PopupHeaderMetrics.contentInset)
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
            .padding(.horizontal, 16)
            .padding(.top, 14)
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
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
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

// MARK: - Tile Container

struct RateTileContainer<Content: View>: View {
    let title: String
    let bannerColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.churBadgeBold())
                    .kerning(1.2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(bannerColor)
                    .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 8))
                Spacer()
            }
            content()
        }
        // Solid rather than 60% opaque, and a wider softer shadow: on the sage
        // hero style each section has to read as its own card lifted off the
        // page, which a translucent fill and a tight shadow never did.
        .background(Color.churTileWhiteBg)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
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
        VStack(spacing: 20) {
            if let best = bestCardSummary {
                RateTileContainer(title: AppLocale.string("BEST CARD TO USE"), bannerColor: .churGold) {
                    PopupBestCardContent(
                        summary: best,
                        card: cards.first(where: { $0.name == best.name }),
                        showFormula: showFormula
                    )
                }
                if !otherCardRates.isEmpty {
                    RateTileContainer(title: AppLocale.string("OTHER GREAT OPTIONS"), bannerColor: .churMediumGray) {
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
                    }.padding(16)
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
                    .padding(.horizontal, 16).padding(.vertical, 20)
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
