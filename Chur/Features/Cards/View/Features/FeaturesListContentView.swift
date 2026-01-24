import SwiftUI
import SwiftData

/// Displays the full list of features for a given credit card (all non-credit benefit types).
/// Features are listed without tracking, checkboxes, or frequency badges.
/// Rows are expandable via a chevron if a description is available.
///
struct FeaturesListContentView: View {
    private enum Constants {
        static let cornerRadius: CGFloat = 16
        static let rowPadding: CGFloat = 20
    }

    let card: CreditCard
    
    /// Exclude benefit types that appear in the Benefits tab.
    private let excludedBenefitTypes: Set<String> = ["credit","lounge_access", "ttp"]
    
    /// Filtered and sorted array of features.
    private var features: [Benefit] {
        card.benefits
            .filter { !excludedBenefitTypes.contains($0.benefitType.lowercased()) }
            .sorted { a, b in
                if a.benefitType != b.benefitType {
                    return a.benefitType.localizedStandardCompare(b.benefitType) == .orderedAscending
                }
                return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
            }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // MARK: - Header
            HStack(alignment: .center, spacing: 12) {
                Text("FEATURES (\(features.count))")
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
                    emptyStateView(message: "No features available.")
                } else if features.isEmpty {
                    emptyStateView(message: "No features available.")
                } else {
                    featuresList
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .padding()
        .background(Color.churOffWhite)
    }
}

// MARK: - Subviews
private extension FeaturesListContentView {

    @ViewBuilder
    func emptyStateView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.churTitle2())
                .foregroundStyle(Color.churLightGray)
            
            Text(message)
                .font(.churCaptionMedium())
                .foregroundStyle(Color.churMediumGray)
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }

    var featuresList: some View {
        ForEach(features, id: \.id) { feature in
            FeatureRow(feature: feature)
                .padding(.vertical, Constants.rowPadding)
                .padding(.horizontal, 20)
            
            if feature.id != features.last?.id {
                Divider().padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let feature: Benefit
    
    // State to manage expansion
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Row: Icon + Title + Chevron
            HStack(alignment: .center, spacing: 12) {
                Text("✨")
                    .font(.churBigTitle4())
                
                Text(feature.displayName)
                    .font(.churRowText())
                    .foregroundStyle(Color.churDarkGray)
                    .lineLimit(1) // Keeps the main row clean
                
                Spacer()
                
                // Show chevron only if description exists
                if !feature.displayDescription.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color.churLightGray)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            
            // Expandable Description
            if isExpanded && !feature.displayDescription.isEmpty {
                Text(feature.displayDescription)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.churMediumGray)
                    .padding(.leading, 34) // Aligns with the start of the title
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .contentShape(Rectangle()) // Makes the whole area tappable
        .onTapGesture {
            guard !feature.displayDescription.isEmpty else { return }
            withAnimation(.snappy(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
}
