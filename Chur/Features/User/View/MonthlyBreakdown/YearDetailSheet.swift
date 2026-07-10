//
//  YearDetailSheet.swift
//  Chur
//
//  Created by Pak Ho on 2/2/26.
//

import SwiftUI
import SwiftData

struct YearDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let year: Int
    let cards: [CreditCard]
    let fees: Int
    let savings: Int
    
    enum SortOption {
        case performance, redeemed, renewal
    }

    @State private var currentSort: SortOption = .performance
    @State private var expandedCardID: String? = nil

    struct CardSnapshot: Identifiable {
        var id: String { card.id }
        let card: CreditCard
        let fee: Int
        let redeemed: Int
        let feeMonth: Int
        let details: [BenefitDetail]
        
        var isNoFee: Bool { fee == 0 }
        var hasData: Bool { fee > 0 || redeemed > 0 }
        
        var recoveryPercentage: Double {
            guard fee > 0 else { return redeemed > 0 ? 10.0 : 0.0 }
            return Double(redeemed) / Double(fee)
        }
    }

    private var cardSnapshots: [CardSnapshot] {
        let snapshots: [CardSnapshot] = cards.compactMap { card in
            guard card.approvedYear <= year else { return nil }
            let yearlyFee = card.annualFee
            
            var cardDetails: [BenefitDetail] = []
            var cardTotalRedeemed = 0
            
            for benefit in card.benefits {
                let records = benefit.usageHistory.filter { $0.year == year }
                if !records.isEmpty {
                    let val = benefit.usageLimit != nil
                        ? records.count * benefit.value
                        : records.reduce(0) { $0 + $1.redeemedAmount }
                    
                    if val > 0 {
                        cardDetails.append(BenefitDetail(name: benefit.displayName, amount: val))
                        cardTotalRedeemed += val
                    }
                }
            }
            
            return CardSnapshot(card: card, fee: yearlyFee, redeemed: cardTotalRedeemed, feeMonth: card.approvedMonth, details: cardDetails)
        }
        
        return snapshots.sorted {
            let firstIsActiveOnly = $0.isNoFee && $0.redeemed == 0
            let secondIsActiveOnly = $1.isNoFee && $1.redeemed == 0
            if firstIsActiveOnly != secondIsActiveOnly { return !firstIsActiveOnly }
            
            switch currentSort {
            case .performance: return $0.recoveryPercentage > $1.recoveryPercentage
            case .redeemed: return $0.redeemed > $1.redeemed
            case .renewal: return $0.feeMonth < $1.feeMonth
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    PatternHeaderBanner(imageName: "HeaderPattern5")

                    DetailSheetTitleBlock(title: "\(year)", subtitle: "SUMMARY")

                    premiumDashboardCard
                        .padding(24)

                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Wallet")
                                .font(.churFootnoteBold())
                                .foregroundStyle(Color.churDarkGray.opacity(0.6))
                            
                            Spacer()
                            
                            sortPickerButton
                        }
                        .padding(.horizontal, 28)

                        VStack(spacing: 12) {
                            ForEach(cardSnapshots) { snapshot in
                                EnhancedCardRow(
                                    snapshot: snapshot,
                                    isExpanded: expandedCardID == snapshot.id,
                                    toggleExpanded: {
                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            expandedCardID = (expandedCardID == snapshot.id) ? nil : snapshot.id
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    Spacer(minLength: 100)
                }
            }
            .background(Color.churOffWhite)
            .ignoresSafeArea()

            SheetDismissButton { dismiss() }
        }
    }

    private var sortPickerButton: some View {
        Button {
            withAnimation(.snappy) {
                switch currentSort {
                case .performance: currentSort = .redeemed
                case .redeemed: currentSort = .renewal
                case .renewal: currentSort = .performance
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: currentSort == .performance ? "percent" : currentSort == .redeemed ? "dollarsign.circle" : "calendar")
                    .font(.churBadgeBold())
                Text(currentSort == .performance ? "By Health" : currentSort == .redeemed ? "By Value" : "By Renewal")
                    .font(.churBadgeBold())
            }
            .foregroundStyle(Color.churOlive)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.churOlive.opacity(0.12)))
        }
    }

    private var premiumDashboardCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OVERALL")
                    .font(.churBadgeBold())
                    .foregroundStyle(.secondary)
                Text("$\(savings - fees)")
                    .font(.churHero())
                    .foregroundStyle((savings - fees) >= 0 ? Color.churOlive : .red)
            }
            Spacer()
            ZStack {
                Circle().stroke(Color.churOffWhite, lineWidth: 8).frame(width: 70, height: 70)
                Circle()
                    .trim(from: 0, to: min(CGFloat(Double(savings)/Double(max(fees, 1))), 1.0))
                    .stroke(
                        LinearGradient(colors: [.churstatusgreen, .churstatusgreen.opacity(0.5)], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 70, height: 70).rotationEffect(.degrees(-90))
                Text(String(format: "%.1fx", Double(savings)/Double(max(fees, 1))))
                    .font(.churCaption())
            }
        }
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 32).fill(.white).shadow(color: .black.opacity(0.04), radius: 12, y: 6))
    }
}

// MARK: - Enhanced Card Row
struct EnhancedCardRow: View {
    let snapshot: YearDetailSheet.CardSnapshot
    let isExpanded: Bool
    let toggleExpanded: () -> Void
    
    private var health: (color: Color, label: String) {
        if snapshot.isNoFee { return (Color.churOlive, snapshot.redeemed > 0 ? "Profit" : "Active") }
        let ratio = Double(snapshot.redeemed) / Double(snapshot.fee)
        if ratio >= 1.0 { return (Color.churOlive, "GREAT") }
        if ratio >= 0.5 { return (Color.green, "Good") }
        return (Color.red.opacity(0.6), "Loss")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(snapshot.card.imageName)
                    .resizable().scaledToFit()
                    .frame(width: 44, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.1), radius: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.card.name)
                        .font(.churRowText())
                        .foregroundStyle(Color.churDarkGray)
                    Text(snapshot.isNoFee ? "" : "Renewal: \(Calendar.current.monthSymbols[snapshot.feeMonth-1])")
                        .font(.churBadgeMedium())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(snapshot.redeemed)").font(.churRowText())
                    Text(health.label).font(.system(size: 8, weight: .black)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(health.color.opacity(0.15)).foregroundStyle(health.color).clipShape(Capsule())
                }
                Image(systemName: "chevron.right").font(.churBadgeBold()).foregroundStyle(Color.churLightGray)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0)).opacity(snapshot.hasData ? 1 : 0)
            }
            .padding(20)
            .contentShape(Rectangle())
            .onTapGesture { if snapshot.hasData { toggleExpanded() } }

            if isExpanded {
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        statPill(label: "FEE", value: "$\(snapshot.fee)", color: .red)
                        statPill(label: "REDEEMED", value: "$\(snapshot.redeemed)", color: Color.churOlive)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)


                    if !snapshot.details.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(snapshot.details) { detail in
                                HStack {
                                    Text(detail.name).font(.churSmallMedium()).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("$\(detail.amount)").font(.churSmallBold())
                                }
                            }
                        }
                        .padding(.horizontal, 24).padding(.bottom, 24)
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 24).fill(isExpanded ? health.color.opacity(0.06) : Color.white)
            .shadow(color: .black.opacity(isExpanded ? 0.04 : 0.02), radius: 8, y: 4))
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.churSubheadline()).foregroundStyle(color)
            Text(label.uppercased()).font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary).tracking(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.5)).overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.1), lineWidth: 1)))
    }
}
