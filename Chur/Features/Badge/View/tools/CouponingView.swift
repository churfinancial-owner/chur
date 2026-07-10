import SwiftUI
import SwiftData

struct CouponingView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var cards: [CreditCard]
    @State private var selectedCategory: CouponCategoryGroup? = nil

    // MARK: - Data

    private var creditEntries: [CouponingEntry] {
        var results: [CouponingEntry] = []
        for card in cards {
            for benefit in card.benefits where benefit.benefitType.lowercased() == "credit" {
                results.append(CouponingEntry(card: card, benefit: benefit))
            }
        }
        return results
    }

    private var totalCreditCount: Int { creditEntries.count }

    private var groupedSections: [CouponGroupedSection] {
        var buckets: [CouponCategoryGroup: [CouponingEntry]] = [:]
        for entry in creditEntries {
            let group = CouponCategoryGroup.from(entry.benefit.displayGroup)
            buckets[group, default: []].append(entry)
        }
        return CouponCategoryGroup.allCases.compactMap { cat in
            guard let entries = buckets[cat], !entries.isEmpty else { return nil }
            return CouponGroupedSection(category: cat, entries: entries)
        }
    }

    private var donutSegments: [DonutSegment] {
        let total = Double(totalCreditCount)
        guard total > 0 else { return [] }
        let gapRadians = 0.04
        var current = Angle.degrees(-90)
        return groupedSections.map { section in
            let sweep = Angle.degrees((Double(section.entries.count) / total) * 360)
            let start = current
            let end = current + sweep - Angle(radians: gapRadians)
            current = current + sweep
            return DonutSegment(category: section.category, count: section.entries.count, start: start, end: end)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // MARK: - Pattern Header
                        PatternHeaderBanner(imageName: "HeaderPattern5")

                        heroHeader
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)

                        if totalCreditCount == 0 {
                            emptyState
                                .padding(.horizontal, 24)
                                .padding(.top, 24)
                        } else {
                            donutChartCard(proxy: proxy)
                                .padding(.horizontal, 24)
                                .padding(.top, 24)

                            VStack(spacing: 16) {
                                ForEach(groupedSections) { section in
                                    carouselSection(section: section)
                                        .id(section.category.rawValue)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                        }

                        Spacer(minLength: 40)
                    }
                }
                .background(Color.churOffWhite)
            }

            SheetDismissButton { dismiss() }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LIFESTYLE")
                .font(.churMicroBold())
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.purple)
                .clipShape(Capsule())

            Text("Couponing")
                .font(.churBigTitle3())
                .foregroundStyle(Color.churDarkGray)

            Text("Credits and perks you receive through your cards.")
                .font(.churCaptionMedium())
                .foregroundStyle(Color.churMediumGray)
                .lineSpacing(2)
        }
    }

    // MARK: - Donut Chart Card

    private func donutChartCard(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(Array(donutSegments.enumerated()), id: \.offset) { _, segment in
                    DonutSegmentShape(
                        startAngle: segment.start,
                        endAngle: segment.end,
                        lineWidth: 28
                    )
                    .stroke(
                        segment.category.color.opacity(
                            selectedCategory == nil || selectedCategory == segment.category ? 1.0 : 0.25
                        ),
                        style: StrokeStyle(lineWidth: 28, lineCap: .round)
                    )
                    .onTapGesture {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedCategory == segment.category {
                                selectedCategory = nil
                            } else {
                                selectedCategory = segment.category
                            }
                        }
                        if selectedCategory != nil {
                            withAnimation {
                                proxy.scrollTo(segment.category.rawValue, anchor: .top)
                            }
                        }
                    }
                }

                // Center label
                VStack(spacing: 2) {
                    Text("\(totalCreditCount)")
                        .font(.churCounter())
                        .foregroundStyle(Color.churDarkGray)
                    Text("coupons")
                        .font(.churFootnoteBold())
                        .foregroundStyle(Color.churMediumGray)
                }
            }
            .frame(width: 200, height: 200)
            .frame(maxWidth: .infinity)

            // Legend
            donutLegend(proxy: proxy)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }

    // MARK: - Donut Legend

    private func donutLegend(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(groupedSections) { section in
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedCategory == section.category {
                                selectedCategory = nil
                            } else {
                                selectedCategory = section.category
                            }
                        }
                        if selectedCategory != nil {
                            withAnimation {
                                proxy.scrollTo(section.category.rawValue, anchor: .top)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(section.category.color)
                                .frame(width: 9, height: 9)
                            Text(section.category.label)
                                .font(.churMicroBold())
                                .foregroundStyle(
                                    selectedCategory == section.category
                                        ? section.category.color
                                        : Color.churMediumGray
                                )
                            Text("\(section.entries.count)")
                                .font(.churMicroBold())
                                .foregroundStyle(Color.churDarkGray)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Carousel Section

    private func carouselSection(section: CouponGroupedSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: section.category.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(section.category.color)

                Text(section.category.label)
                    .font(.churSmallBold())
                    .foregroundStyle(Color.churMediumGray)
                    .tracking(1)

                Spacer()

                Text("\(section.entries.count)")
                    .font(.churSectionHeader())
                    .foregroundStyle(section.category.color)
            }

            // Horizontal carousel of coupon tiles
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(section.entries) { entry in
                        couponTile(entry: entry, accentColor: section.category.color)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        .opacity(selectedCategory == nil || selectedCategory == section.category ? 1.0 : 0.4)
        .animation(.easeInOut(duration: 0.2), value: selectedCategory)
    }

    // MARK: - Coupon Tile

    private func couponTile(entry: CouponingEntry, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Card image
            Image(entry.card.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Benefit name
            Text(entry.benefit.displayName)
                .font(.churCaption())
                .foregroundStyle(Color.churDarkGray)
                .lineLimit(2)

            // Card name
            Text(entry.card.name)
                .font(.churSmallMedium())
                .foregroundStyle(Color.churMediumGray)
                .lineLimit(2)
        }
        .padding(14)
        .frame(width: 170, height: 130, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: accentColor.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private var emptyState: some View {
        EmptyStatePlaceholder(icon: "scissors", title: "No credits yet", subtitle: "Add a card with credit benefits to see them here.")
    }
}

// MARK: - Donut Segment Shape

private struct DonutSegmentShape: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = (min(rect.width, rect.height) / 2) - (lineWidth / 2)
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return path
    }
}

// MARK: - Supporting Types

private struct DonutSegment {
    let category: CouponCategoryGroup
    let count: Int
    let start: Angle
    let end: Angle
}

private struct CouponGroupedSection: Identifiable {
    let category: CouponCategoryGroup
    let entries: [CouponingEntry]
    var id: String { category.rawValue }
}

private struct CouponingEntry: Identifiable {
    let card: CreditCard
    let benefit: Benefit
    var id: String { "\(card.id)-\(benefit.id)" }
}

private enum CouponCategoryGroup: String, CaseIterable, Identifiable {
    case dining = "lifestyle_dining"
    case shopping = "lifestyle_shopping"
    case entertainment = "lifestyle_entertainment"
    case convenience = "lifestyle_convenience"
    case travel = "lifestyle_travel"
    case checkedBags = "lifestyle_checkedbags"
    case business = "business"
    case other = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dining:         return "DINING"
        case .shopping:       return "SHOPPING"
        case .entertainment:  return "ENTERTAINMENT"
        case .convenience:    return "CONVENIENCE"
        case .travel:         return "TRAVEL"
        case .checkedBags:    return "CHECKED BAGS"
        case .business:       return "BUSINESS"
        case .other:          return "OTHER"
        }
    }

    var icon: String {
        switch self {
        case .dining:         return "fork.knife"
        case .shopping:       return "bag.fill"
        case .entertainment:  return "tv.fill"
        case .convenience:    return "car.fill"
        case .travel:         return "airplane"
        case .checkedBags:    return "suitcase.fill"
        case .business:       return "briefcase.fill"
        case .other:          return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .dining:         return .churCouponDining
        case .shopping:       return .churCouponShopping
        case .entertainment:  return .churCouponEntertainment
        case .convenience:    return .churCouponConvenience
        case .travel:         return .churCouponTravel
        case .checkedBags:    return .churCouponCheckedBags
        case .business:       return .churCouponBusiness
        case .other:          return .churGold
        }
    }

    static func from(_ displayGroup: String) -> CouponCategoryGroup {
        CouponCategoryGroup(rawValue: displayGroup) ?? .other
    }
}
