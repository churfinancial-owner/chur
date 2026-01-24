//
//  CardCarouselItem.swift
//  Chur
//  View of a card such as logo name note in card view
//  Created by Pak Ho on 1/26/26.
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
                        .border(Color.churOffWhite, width: 1) 
                }
                else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardColor.gradient)
                }
                
                // MARK: - Content Layer
                VStack(alignment: .leading, spacing: 0) {
                    // TOP: Edit Button
                    HStack(alignment: .top) {
                        Spacer()
                        
                        Button(action: onEdit) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.churRatebubbleOliveText)
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .background(.white.opacity(0.95))
                                .clipShape(Circle())
                        }
                    }
                    
                    Spacer(minLength: 6)
                    
                    // MIDDLE: Note
                    ZStack {
                        if !card.note.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 14, weight: .bold))
                                
                                Text(card.note)
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .lineLimit(noteLineLimit)
                                    .truncationMode(.tail)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: geometry.size.width * noteMaxWidthFactor)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .background(Color.black.opacity(0.2))
                            .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 6)
                    
                    // BOTTOM: Network
                    HStack {
                        Spacer()
                        if showsCustomNetwork {
                            Text(card.network)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .italic()
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.85)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial)
                                .background(Color.black.opacity(0.2))
                                .clipShape(Capsule())
                                .frame(maxWidth: geometry.size.width * 0.46, alignment: .trailing)
                        }
                    }
                }
                .padding(16) // Slightly more padding to align with the scaled card image
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
