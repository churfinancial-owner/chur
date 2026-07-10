//
//  CardCarouselItem.swift
//  Chur
//

import SwiftUI
import SwiftData

struct CardCarouselItem: View {
    let card: CreditCard
    let onEdit: () -> Void
    
    var cardColor: Color {
        .cardColor(for: card.issuer)
    }

    private var defaultNetwork: String {
        CardDatabase.getCard(id: card.templateID ?? "")?.network ?? card.network
    }

    private var showsCustomNetwork: Bool { card.network != defaultNetwork }
    private var noteLineLimit: Int {
        showsCustomNetwork ? 3 : 4
    }

    private var noteMaxWidthFactor: CGFloat {
        showsCustomNetwork ? 0.78 : 0.86
    }
    
    var body: some View {
        let cardAsset = UIImage(named: card.imageName)
        
        GeometryReader { geometry in
            ZStack {
                // MARK: - Background Layer
                if let uiImage = cardAsset {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardColor.gradient)
                }
                
                // MARK: - Content Layer
                VStack(alignment: .leading, spacing: 0) {
                    
                    Spacer(minLength: 10)
                    
                    ZStack {
                        if !card.note.isEmpty && card.noteIsVisible {
                            Button(action: onEdit) {
                                HStack(spacing: 4) {
                                    Image(systemName: "note.text")
                                        .font(.churSmallBold())
                                    Text(card.note)
                                        .font(.churSmallBold())
                                        .lineLimit(noteLineLimit)
                                        .truncationMode(.tail)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: geometry.size.width * noteMaxWidthFactor)
                                .foregroundStyle(Color(hex: card.noteTextColor))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background {
                                    ZStack {
                                        Capsule().fill(Color(hex: card.noteBgColor).opacity(0.93))
                                    }
                                }
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 10)

                    if showsCustomNetwork {
                        HStack {
                            Spacer()
                            Text(card.network)
                                .font(.churSmallBold())
                                .italic()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial)
                                .background(Color.black.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
        }
        .aspectRatio(1.586, contentMode: .fit)
    }
}
