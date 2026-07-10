//
//  Cards_Add_Card_CardDatabaserow.swift
//  Chur
//
//  Created by Pak Ho on 2/15/26.
//

import SwiftUI
import SwiftData

struct CardDatabaseRow: View {
    let template: CardTemplate
    let addedCount: Int
    let onAdd: () -> Void
    let onRemove: (() -> Void)?

    init(template: CardTemplate, addedCount: Int, onAdd: @escaping () -> Void, onRemove: (() -> Void)? = nil) {
        self.template = template
        self.addedCount = addedCount
        self.onAdd = onAdd
        self.onRemove = onRemove
    }

    var cardColor: Color {
        .cardColor(for: template.issuer)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Card image with colored fallback
            if let uiImage = UIImage(named: template.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(cardColor)
                    .frame(width: 60, height: 38)
                    .overlay {
                        VStack(spacing: 2) {
                            Text(template.issuer)
                                .font(.churBadge())
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text(template.network)
                                .font(.churBadge())
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
            }
            
            // Card info
            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(.churCaption())
                    .foregroundStyle(Color.churDarkGray)
                    .lineLimit(1)
                
                Text(template.issuer)
                    .font(.churSmall())
                    .foregroundStyle(Color.churMediumGray)
            }
            
            Spacer()
            
            // Add / Remove controls
            if addedCount > 0 {
                HStack(spacing: 6) {
                    // Minus button
                    Button {
                        onRemove?()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.churTitle())
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    // Count badge
                    Text("\(addedCount)")
                        .font(.churCaption())
                        .foregroundStyle(Color.churOlive)
                        .frame(minWidth: 20)

                    // Plus button
                    Button {
                        onAdd()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.churTitle())
                            .foregroundStyle(Color.churOlive)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Just the plus button
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.churBigTitle3())
                        .foregroundStyle(Color.churOlive)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
}
