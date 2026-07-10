//
//  MonthDetailSheetComponents.swift
//  Chur
//
//  Created by Pak Ho on 4/15/26.
//

import SwiftUI

// MARK: - Shared Sheet Header

struct DetailSheetTitleBlock: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.churBigTitle3())
                .foregroundStyle(Color.churDarkGray)
            Text(subtitle)
                .font(.churSmallBold())
                .foregroundStyle(Color.churMediumGray)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}

// MARK: - Shared Data Models
struct BenefitDetail: Identifiable {
    let id = UUID()
    let name: String
    let amount: Int
}

struct GroupedBenefit: Identifiable {
    let id = UUID()
    let card: CreditCard
    let totalAmount: Int
    let details: [BenefitDetail]
}

// MARK: - Shared View Component
struct BenefitGroupRow: View {
    let group: GroupedBenefit
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(group.card.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.06), lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.card.name)
                        .font(.churCaption())
                        .foregroundStyle(Color.churDarkGray)
                        .lineLimit(1)

                    Text(group.card.issuer)
                        .font(.churSmall())
                        .foregroundStyle(Color.churMediumGray)
                        .lineLimit(1)
                }

                Spacer()

                Text("+$\(group.totalAmount)")
                    .font(.churRowText())
                    .foregroundStyle(.green)

                Image(systemName: "chevron.right")
                    .font(.churBadgeBold())
                    .foregroundStyle(Color.churLightGray)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(group.details) { detail in
                        HStack {
                            Text(detail.name)
                                .font(.churFootnoteMedium())
                                .foregroundStyle(Color.churMediumGray)
                            Spacer()
                            Text("$\(detail.amount)")
                                .font(.churFootnoteBold())
                                .foregroundStyle(Color.churDarkGray)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .padding(.leading, 54)
                        
                        if detail.id != group.details.last?.id {
                            Divider().padding(.leading, 70).opacity(0.3)
                        }
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
