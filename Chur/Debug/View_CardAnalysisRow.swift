
//
//  View_CardAnalysisRow.swift
//  Chur
//
//  Card analysis row for the calculator popup breakdown view
//

import SwiftUI

struct CardAnalysisRow: View {
    let analysis: CalculatorPopup.CardAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Card image or placeholder
                if let uiImage = UIImage(named: analysis.card.imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(cardColor(for: analysis.card.issuer))
                        .frame(width: 60, height: 38)
                        .overlay {
                            Text(analysis.card.issuer.prefix(1))
                                .font(.churCaption())
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.card.name)
                        .font(.churRowText())
                        .foregroundStyle(analysis.isFiltered ? Color.churMediumGray : Color.churDarkGray)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(analysis.card.network)
                            .font(.churSmall())
                            .foregroundStyle(Color.churMediumGray)
                        
                        if !analysis.isFiltered {
                            if let best = analysis.bestReward {
                                Text("•")
                                    .font(.churSmall())
                                    .foregroundStyle(Color.churLightGray)
                                
                                Text(formattedRate(best.breakdown.netRate))
                                    .font(.churFootnoteBold())
                                    .foregroundStyle(effectiveRateTextColor(best.breakdown.netRate, isPrimary: true))
                            } else {
                                Text("•")
                                    .font(.churSmall())
                                    .foregroundStyle(Color.churLightGray)
                                
                                Text("No match")
                                    .font(.churMicroMedium())
                                    .foregroundStyle(Color.churMediumGray)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Status indicator
                if analysis.isFiltered {
                    Image(systemName: "xmark.circle.fill")
                        .font(.churBigTitle4())
                        .foregroundStyle(Color.red.opacity(0.7))
                } else if analysis.bestReward != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.churBigTitle4())
                        .foregroundStyle(Color.green)
                } else {
                    Image(systemName: "minus.circle.fill")
                        .font(.churBigTitle4())
                        .foregroundStyle(Color.churLightGray)
                }
            }
            
            // Card-level info badges (country, cross-border status)
            if !analysis.isFiltered {
                HStack(spacing: 6) {
                    if !analysis.card.country.isEmpty {
                        Text("Card: \(analysis.card.country)")
                            .font(.churBadgeMedium())
                            .foregroundStyle(Color.churMediumGray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.churOffWhite)
                            .clipShape(Capsule())
                    }
                    
                    if analysis.isCrossBorder {
                        Text("Cross-border")
                            .font(.churBadgeBold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.7))
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 6)
                .padding(.leading, 72) // Align with card name
            }
            
            // Details section (collapsible via disclosure)
            if !analysis.isFiltered && !analysis.matchingRewards.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(analysis.matchingRewards.enumerated()), id: \.offset) { index, match in
                            let isBest = analysis.bestReward?.reward.id == match.reward.id
                            let bd = match.breakdown
                            
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(isBest ? Color.churOlive : Color.churLightGray)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // Rate multiplier and effective rate
                                    HStack(spacing: 6) {
                                        Text("\(String(format: "%.1fx", match.reward.rate))")
                                            .font(.churFootnoteBold())
                                            .foregroundStyle(isBest ? Color.churOlive : Color.churDarkGray)
                                        
                                        Text("=")
                                            .font(.churSmall())
                                            .foregroundStyle(Color.churLightGray)
                                        
                                        Text(effectiveRateFormulaText(breakdown: bd))
                                            .font(.churFootnoteBold())
                                            .foregroundStyle(effectiveRateTextColor(bd.netRate, isPrimary: isBest))
                                    }
                                    
                                    // Match reason
                                    Text(match.matchReason)
                                        .font(.churSmall())
                                        .foregroundStyle(Color.churMediumGray)
                                    
                                    // Categories
                                    if let categories = match.reward.categories {
                                        Text(categories.joined(separator: ", "))
                                            .font(.churBadge())
                                            .foregroundStyle(Color.churLightGray)
                                    }
                                    
                                    // Calculation details (debug)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Program: \(bd.rewardProgramName)")
                                            .font(.churBadge())
                                        
                                        Text("Point value: \(String(format: "%.6f", bd.pointValue)) \(bd.pointValueCurrency)/pt")
                                            .font(.churBadge())
                                        
                                        if bd.boostMultiplier > 1.0 {
                                            Text("Boost: \(String(format: "%.2fx", bd.boostMultiplier))")
                                                .font(.churBadge())
                                        }
                                        
                                        Text("Effective: \(String(format: "%.2f", bd.baseRate * 100))%")
                                            .font(.churBadge())
                                        
                                        if bd.fxFeeRate > 0 {
                                            Text("FX fee: -\(String(format: "%.2f", bd.fxFeeRate * 100))%")
                                                .font(.churBadge())
                                                .foregroundStyle(Color.orange)
                                            
                                            Text("Net: \(String(format: "%.2f", bd.netRate * 100))%")
                                                .font(.churBadge())
                                        }
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.churOffWhite.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack {
                        Text("View \(analysis.matchingRewards.count) reward\(analysis.matchingRewards.count == 1 ? "" : "s")")
                            .font(.churSmallMedium())
                            .foregroundStyle(Color.churOlive)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.churBadgeBold())
                            .foregroundStyle(Color.churOlive)
                    }
                }
                .tint(Color.churOlive)
                .padding(.top, 12)
            } else if analysis.isFiltered, let reason = analysis.filterReason {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.churSmall())
                        .foregroundStyle(Color.red.opacity(0.7))
                    
                    Text(reason)
                        .font(.churSmall())
                        .foregroundStyle(Color.red.opacity(0.8))
                }
                .padding(.top, 8)
            }
            
            // Show blocked payment method rewards
            if !analysis.excludedPaymentMethodRewards.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(analysis.excludedPaymentMethodRewards.enumerated()), id: \.offset) { _, blocked in
                        HStack(spacing: 6) {
                            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                                .font(.churSmall())
                                .foregroundStyle(.orange)
                            
                            Text("\(String(format: "%.1fx", blocked.reward.rate))")
                                .font(.churSmallBold())
                                .foregroundStyle(.orange)
                            
                            Text("(\(formattedRate(blocked.effectiveRate)))")
                                .font(.churMicro())
                                .foregroundStyle(.orange.opacity(0.7))
                            
                            Text(blocked.paymentMethod)
                                .font(.churMicroMedium())
                                .foregroundStyle(Color.churMediumGray)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(analysis.isFiltered ? Color.churLightGray.opacity(0.2) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(analysis.bestReward != nil ? Color.churOlive.opacity(0.3) : Color.clear, lineWidth: 2)
                )
        )
    }
    
    private func cardColor(for issuer: String) -> Color {
        .cardColor(for: issuer)
    }

    private func effectiveRateTextColor(_ rate: Double, isPrimary: Bool) -> Color {
        if rate < 0 {
            return isPrimary ? Color(red: 0.78, green: 0.25, blue: 0.42) : Color(red: 0.72, green: 0.36, blue: 0.46)
        }
        return isPrimary ? Color.churOlive : Color.churMediumGray
    }

    /// Formats an effective rate as a percentage, e.g. "5%", "9.75%", "-1.25%"
    private func formattedRate(_ rate: Double) -> String {
        let pct = rate * 100
        if pct.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(String(format: "%.0f", pct))%"
        } else if (pct * 10).truncatingRemainder(dividingBy: 1) == 0 {
            return "\(String(format: "%.1f", pct))%"
        } else {
            return "\(String(format: "%.2f", pct))%"
        }
    }

    private func effectiveRateFormulaText(breakdown bd: CalculatorPopup.RateBreakdown) -> String {
        let base = formattedRate(bd.baseRate)
        let net = formattedRate(bd.netRate)
        guard bd.fxFeeRate > 0 else { return base }
        let fx = formattedRate(bd.fxFeeRate)
        return "\(base) - \(fx) FX = \(net)"
    }
}

