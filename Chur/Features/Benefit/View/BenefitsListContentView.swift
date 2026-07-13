import SwiftUI
import SwiftData

/// Displays the full list of benefits for a given credit card, with a frequency filter picker
/// in the header. Each benefit is rendered as a `BenefitCheckboxRow` (name + frequency badge).
/// This view is purely presentational — filtering logic lives in `filteredBenefits` and
/// `allDisplayOptions`, while per-row interactions (toggle, detail sheet) live in `BenefitCheckboxRow`.

struct BenefitsListContentView: View {
    private enum Constants {
        static let cornerRadius: CGFloat = 16
        static let rowPadding: CGFloat = 20
    }

    let card: CreditCard
    /// The currently active frequency filter. `nil` means "show all".
    /// This binding is owned by the parent so the same filter can be shared across views.
    @Binding var selectedFrequency: String?
    
    init(card: CreditCard, selectedFrequency: Binding<String?>) {
        self.card = card
        self._selectedFrequency = selectedFrequency
    }
    
    /// Bumped when the mock date changes (time travel) to force SwiftUI to re-evaluate
    /// computed properties that depend on `Date.current()`.
    #if DEBUG
    @State private var dateRefreshTick: Int = 0
    #endif

    // MARK: - Color Mapping

    /// Returns the tint color for the filter bubble based on the active frequency selection.
    /// Clear when no filter is active so the bubble appears unselected.
    private var activeFilterColor: Color {
        guard let freq = selectedFrequency?.lowercased() else { return Color.clear }
        switch freq {
        case "expiring":  return .pink
        case "available": return Color.churOlive
        default:          return ChurStatusPill.color(for: freq)
        }
    }

    // MARK: - Filtering & Sorting

    /// The canonical display order for frequency types in the sorted list.
    private let frequencyOrder = ["monthly", "quarterly", "semi-annual", "annual", "one-time", "quadrennial", "ongoing"]

    /// Only these benefit types are shown in the list. Others (e.g. points, offers) are excluded.
    private let allowedBenefitTypes: Set<String> = ["credit","lounge_access","ttp"]

    /// Sort order for benefit types within the same frequency group.
    private let benefitTypeOrder = ["credit", "lounge_access", "ttp"]

    /// Benefits whose type is not in `allowedBenefitTypes` — shown in the Features section.
    private var featureBenefits: [Benefit] {
        card.benefits
            .filter { !allowedBenefitTypes.contains($0.benefitType.lowercased()) }
            .sorted { a, b in
                if a.benefitType != b.benefitType {
                    return a.benefitType.localizedStandardCompare(b.benefitType) == .orderedAscending
                }
                return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
            }
    }

    /// The filtered and sorted array of benefits to display, derived from `card.benefits`.
    private var filteredBenefits: [Benefit] {
        card.benefits
            .filter { benefit in
                guard allowedBenefitTypes.contains(benefit.benefitType.lowercased()) else { return false }
                
                // Check basic active status (isActive flag and absolute date ranges)
                guard benefit.isCurrentlyActive else { return false }

                // Delayed benefits are included (shown grayed out) — skip further checks for them
                if benefit.isDelayed(approvedMonth: card.approvedMonth, approvedYear: card.approvedYear) {
                    // Delayed benefits only show in "All" (no filter) view
                    return selectedFrequency == nil
                }

                // REMOVED: The oneTimeGracePeriodDays logic.
                // One-time benefits now stay in the list (dimmed/checked) indefinitely after use
                // so the view hierarchy remains stable during historical logging.

                // No active filter — show everything that passed the checks above
                guard let freq = selectedFrequency else { return true }

                let analyzer = BenefitUsageAnalyzer(benefit: benefit, approvedMonth: card.approvedMonth)

                // "Expiring" quick filter
                if freq.lowercased() == "expiring" {
                    guard let expiryDate = benefit.effectiveExpiryDate() else { return false }
                    let hasBalance = (analyzer.remainingBalance() ?? 0) > 0
                    return hasBalance
                        && ReminderTiming.isInWarningWindow(expiry: expiryDate)
                }

                // IMPROVED: "Available" quick filter
                if freq.lowercased() == "available" {
                    if analyzer.isUnlimited { return true }
                    
                    if benefit.frequency.lowercased() == "one-time" {
                        // FIX: If we are specifically viewing the One-Time frequency,
                        // keep the benefit in the 'Available' view while logging so the sheet stays open.
                        let isOneTimeFilterActive = selectedFrequency?.lowercased() == "one-time"
                        return benefit.usageHistory.isEmpty || isOneTimeFilterActive
                    }
                    
                    return !analyzer.isFullyRedeemedThisPeriod()
                }

                // Standard frequency filter: exact match (case-insensitive)
                return benefit.frequency.lowercased() == freq.lowercased()
            }
            .sorted { a, b in
                // Sort order: active → locked (needs activation) → delayed
                let aDelayed = a.isDelayed(approvedMonth: card.approvedMonth, approvedYear: card.approvedYear)
                let bDelayed = b.isDelayed(approvedMonth: card.approvedMonth, approvedYear: card.approvedYear)
                let aLocked = a.needsActivation(approvedMonth: card.approvedMonth)
                let bLocked = b.needsActivation(approvedMonth: card.approvedMonth)
                
                // Assign group: 0 = active, 1 = locked, 2 = delayed
                let aGroup = aDelayed ? 2 : (aLocked ? 1 : 0)
                let bGroup = bDelayed ? 2 : (bLocked ? 1 : 0)
                if aGroup != bGroup { return aGroup < bGroup }
                
                let aIndex = frequencyOrder.firstIndex(of: a.frequency.lowercased()) ?? Int.max
                let bIndex = frequencyOrder.firstIndex(of: b.frequency.lowercased()) ?? Int.max
                if aIndex != bIndex { return aIndex < bIndex }
                
                let aTypeIndex = benefitTypeOrder.firstIndex(of: a.benefitType.lowercased()) ?? Int.max
                let bTypeIndex = benefitTypeOrder.firstIndex(of: b.benefitType.lowercased()) ?? Int.max
                if aTypeIndex != bTypeIndex { return aTypeIndex < bTypeIndex }
                
                return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
            }
    }

    /// Count of benefits available for redemption (active, not locked, not fully redeemed).
    private var availableForRedemptionCount: Int {
        filteredBenefits.filter { benefit in
            guard !benefit.isLocked(approvedMonth: card.approvedMonth, approvedYear: card.approvedYear) else { return false }
            let analyzer = BenefitUsageAnalyzer(benefit: benefit, approvedMonth: card.approvedMonth)
            if analyzer.isUnlimited { return true }
            
            if benefit.frequency.lowercased() == "one-time" {
                // Support sticky count while viewing the One-Time filter
                return benefit.usageHistory.isEmpty || selectedFrequency?.lowercased() == "one-time"
            }
            
            return !analyzer.isFullyRedeemedThisPeriod()
        }.count
    }

    // MARK: - Picker Options

    /// Builds the list of frequency options shown in the filter picker.
    private var allDisplayOptions: [String] {
        let definedOrder = ["One-Time", "Monthly", "Quarterly", "Semi-Annual", "Annual", "Quadrennial", "Ongoing"]
        let available = Set(card.benefits.map { $0.frequency.capitalized })

        var options = available
        if let current = selectedFrequency,
           current.lowercased() != "expiring",
           current.lowercased() != "available" {
            options.insert(current.capitalized)
        }

        let ordered = definedOrder.filter { options.contains($0) }
        let unknown = options.subtracting(definedOrder).sorted()
        return ordered + unknown
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // MARK: - Benefits Card
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Header
                HStack(alignment: .center, spacing: 12) {

                    // MARK: - Filter Bubble Picker
                    Picker("", selection: $selectedFrequency) {
                        Text("ALL").tag(String?.none)

                        Section("Quick Filters") {
                            Text("✅ AVAILABLE").tag(String?.some("Available"))
                            Text("⏰ EXPIRING").tag(String?.some("Expiring"))
                        }

                        Section("By Frequency") {
                            ForEach(allDisplayOptions, id: \.self) { freq in
                                Text(freq.uppercased()).tag(String?.some(freq))
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(.clear)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(activeFilterColor)

                            Capsule()
                                .stroke(selectedFrequency == nil ? Color.churLightGray : activeFilterColor, lineWidth: 1)

                            HStack(spacing: 6) {
                                Text((selectedFrequency ?? "ALL").uppercased())
                                    .font(.churSmallBold())
                                    .foregroundStyle(selectedFrequency == nil ? Color.churMediumGray : .white)
                                    .fixedSize()

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .heavy))
                                    .foregroundStyle(selectedFrequency == nil ? Color.churMediumGray : .white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                    )
                    .id("global_frequency_picker")

                    // MARK: - Benefit Count Label
                    Text("BENEFITS (\(filteredBenefits.count))")
                        .font(.churSmallBold())
                        .foregroundStyle(Color.churOlive)
                        .tracking(1.0)

                    Spacer()
                }
                .padding([.horizontal, .top], 20)
                .padding(.bottom, 12)

                Divider()
                    .padding(.horizontal, 20)

                // MARK: - Content
                VStack(spacing: 0) {
                    if card.benefits.isEmpty {
                        emptyStateView(message: "No benefits available.")
                    } else if filteredBenefits.isEmpty {
                        emptyStateView(message: selectedFrequency?.lowercased() == "expiring"
                            ? "No benefits in their expiry warning window."
                            : selectedFrequency?.lowercased() == "available"
                            ? "All benefits have been fully redeemed."
                            : "No \(selectedFrequency?.lowercased() ?? "") perks found."
                        )
                    } else {
                        benefitsList
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))

            // MARK: - Features Card
            if !featureBenefits.isEmpty {
                featuresSection
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            }
        }
        .padding()
        .background(Color.churOffWhite)
        .animation(.snappy, value: selectedFrequency)
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .timeTravelDateChanged)) { _ in
            dateRefreshTick += 1
        }
        .id(dateRefreshTick)
        #endif
    }
}

// MARK: - Subviews
private extension BenefitsListContentView {

    @ViewBuilder
    func emptyStateView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "gift")
                .font(.churTitle2())
                .foregroundStyle(Color.churLightGray)
            
            Text(message)
                .font(.churCaptionMedium())
                .foregroundStyle(Color.churMediumGray)
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }

    var benefitsList: some View {
        ForEach(filteredBenefits, id: \.id) { benefit in
            BenefitCheckboxRow(
                benefit: benefit,
                approvedMonth: card.approvedMonth,
                approvedYear: card.approvedYear
            )
                .padding(.vertical, Constants.rowPadding)
                .padding(.horizontal, 20)

            if benefit.id != filteredBenefits.last?.id {
                Divider().padding(.horizontal, 20)
            }
        }
    }

    var featuresSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text("FEATURES (\(featureBenefits.count))")
                    .font(.churSmallBold())
                    .foregroundStyle(Color.churOlive)
                    .tracking(1.0)
                Spacer()
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            Divider().padding(.horizontal, 20)

            ForEach(featureBenefits, id: \.id) { feature in
                FeatureRow(feature: feature)
                    .padding(.vertical, Constants.rowPadding)
                    .padding(.horizontal, 20)

                if feature.id != featureBenefits.last?.id {
                    Divider().padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let feature: Benefit

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text("✨")
                    .font(.churBigTitle4())

                Text(feature.displayName)
                    .font(.churRowText())
                    .foregroundStyle(Color.churDarkGray)
                    .lineLimit(1)

                Spacer()

                if !feature.displayDescription.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.churBadgeBold())
                        .foregroundStyle(Color.churLightGray)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }

            if isExpanded && !feature.displayDescription.isEmpty {
                Text(feature.displayDescription)
                    .font(.churSmallMedium())
                    .foregroundStyle(Color.churMediumGray)
                    .padding(.leading, 34)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !feature.displayDescription.isEmpty else { return }
            withAnimation(.snappy(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
}
