//
//  NearbyStateViews.swift
//  Chur
//
//  Created by Pak Ho on 4/8/26.
//

import SwiftUI

// MARK: - Permission Prompt
struct LocationPermissionPrompt: View {
    let onRequestPermission: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.circle").font(.churHero()).foregroundStyle(Color.churOlive)
            Text("Enable Location").font(.headline)
            Text("We'll show you the best cards for places near you").multilineTextAlignment(.center)
            Button(action: onRequestPermission) {
                Text("Enable Location").padding().background(Color.churOlive).foregroundColor(.white).cornerRadius(10)
            }
        }.padding()
    }
}

// MARK: - Permission Denied
struct LocationPermissionDenied: View {
    let errorMessage: String?
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash").font(.churHero()).foregroundStyle(.gray)
            Text("Location Disabled").font(.headline)
            Text(errorMessage ?? "Please enable in settings").multilineTextAlignment(.center)
        }.padding()
    }
}

// MARK: - Error State
struct LocationErrorView: View {
    let errorMessage: String
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.churHero()).foregroundStyle(.orange)
            Text("Search Failed").font(.headline)
            Text(errorMessage).multilineTextAlignment(.center)
            Button("Try Again", action: onRetry)
        }.padding()
    }
}

// MARK: - Loading State
/// Shown while a nearby search (including a throttled-retry delay) is in flight and no
/// results have arrived yet — without this, that wait renders as blank space, which reads
/// as the app being unresponsive rather than loading.
struct NearbyLoadingState: View {
    @State private var pulse = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    NearbyLoadingCard()
                }
            }
            .padding(.vertical, 10)
            .opacity(pulse ? 0.5 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        }
        .onAppear { pulse = true }
    }
}

private struct NearbyLoadingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.churLightGray.opacity(0.3))
                    .frame(width: 120, height: 16)
                Spacer(minLength: 4)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.churLightGray.opacity(0.3))
                    .frame(width: 24, height: 24)
            }

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.churLightGray.opacity(0.3))
                    .frame(width: 60, height: 38)

                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.churLightGray.opacity(0.3))
                        .frame(width: 80, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.churLightGray.opacity(0.3))
                        .frame(width: 50, height: 20)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(width: 280, height: 110)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Generic Empty State
struct LocationEmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "mappin.slash").font(.churBigTitle3()).foregroundStyle(.gray)
            Text("No places found nearby").foregroundColor(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

// MARK: - Wallet Empty State
struct NearbyWalletEmptyState: View {
    @State private var showAddCards = false
    
    var body: some View {
        Button {
            showAddCards = true
        } label: {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.churOlive.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "creditcard.and.123")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(Color.churOlive)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.churSectionHeader())
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
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .padding(.horizontal, 24)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showAddCards) {
            CardsView_AddCardView()
        }
    }
}
