//
//  CardsEmptyWalletView.swift
//  Chur
//
//  Shows recommendations when the user has zero cards in their wallet.
//

import SwiftUI

struct CardsEmptyWalletView: View {
    @Binding var showingAddCard: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // 1. Illustration / Icon Section
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.churOlive.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "creditcard.and.123")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(Color.churOlive)
                }
                
                VStack(spacing: 8) {
                    Text("Your wallet is empty")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.churDarkGray)

                    Text("Add your credit cards to start tracking\nbenefits and maximizing your rewards.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(Color.churMediumGray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 32)
                
                Button {
                    showingAddCard = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("Add Your First Card")
                            .font(.churSectionHeader())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.churOlive)
                            .shadow(color: Color.churOlive.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
            )
            .padding(.horizontal)
            
        }
    }
}
