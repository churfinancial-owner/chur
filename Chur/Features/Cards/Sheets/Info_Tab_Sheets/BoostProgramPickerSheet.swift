import SwiftUI
import SwiftData

struct BoostProgramPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let card: CreditCard

    @Query private var users: [User]
    private var user: User? { users.first }

    /// The program that applies to this card's issuer — guaranteed non-nil since
    /// the sheet should only be presented when boostProgram != nil.
    private var program: BoostProgram? { card.boostProgram }

    /// The currently enrolled tier name for this program, if any.
    private var currentTierName: String? {
        guard let id = program?.id else { return nil }
        return user?.boostEnrollments[id]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView

                    if let program {
                        tiersSection(program: program)
                        noneRow(program: program)
                        if let footnote = program.footnote {
                            footnoteView(text: footnote)
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding()
            }
            .background(Color.churOffWhite)
            .navigationTitle(program?.name ?? "Relationship Boost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.churRowText())
                        .fontWeight(.bold)
                        .foregroundStyle(Color.churOlive)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 0) {
            Text("🏦")
                .font(.churBigTitle1())

            if let program {
                Text("Select your \(card.issuer) \(program.name) tier to apply your relationship bonus to this card's earning rates.")
                    .font(.churCaptionRegular())
                    .foregroundStyle(Color.churMediumGray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Tiers

    private func tiersSection(program: BoostProgram) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR TIER")
                .font(.churSmallBold())
                .foregroundStyle(Color.churOlive)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(program.tiers, id: \.name) { tier in
                    TierRow(
                        tier: tier,
                        isSelected: currentTierName == tier.name
                    ) {
                        select(tier: tier.name, in: program)
                    }

                    if tier.name != program.tiers.last?.name {
                        Divider().padding(.horizontal, 16).opacity(0.5)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    private func noneRow(program: BoostProgram) -> some View {
        Button {
            select(tier: nil, in: program)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Not enrolled")
                        .font(.churRowTextMedium())
                        .foregroundStyle(Color.churDarkGray)
                    Text("Use base earning rates only")
                        .font(.churFootnote())
                        .foregroundStyle(Color.churMediumGray)
                }
                Spacer()
                Image(systemName: currentTierName == nil ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(currentTierName == nil ? Color.churOlive : Color.churLightGray.opacity(0.5))
                    .font(.churBigTitle4())
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func footnoteView(text: String) -> some View {
        Text(text)
            .font(.churSmall())
            .foregroundStyle(Color.churMediumGray)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    // MARK: - Logic

    private func select(tier: String?, in program: BoostProgram) {
        guard let user else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let tier {
                user.boostEnrollments[program.id] = tier
            } else {
                user.boostEnrollments.removeValue(forKey: program.id)
            }
        }
    }
}

// MARK: - Tier Row

private struct TierRow: View {
    let tier: BoostTier
    let isSelected: Bool
    let onTap: () -> Void

    private var bonusLabel: String {
        let pct = Int((tier.multiplier - 1.0) * 100)
        return "+\(pct)% bonus"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tier.name)
                        .font(.churRowText())
                        .foregroundStyle(Color.churDarkGray)
                    Text(tier.description)
                        .font(.churFootnote())
                        .foregroundStyle(Color.churMediumGray)
                }

                Spacer()

                Text(bonusLabel)
                    .font(.churFootnoteBold())
                    .foregroundStyle(isSelected ? .white : Color.churOlive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isSelected ? Color.churOlive : Color.churOlive.opacity(0.1))
                    .clipShape(Capsule())

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.churOlive : Color.churLightGray.opacity(0.5))
                    .font(.churBigTitle4())
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}
