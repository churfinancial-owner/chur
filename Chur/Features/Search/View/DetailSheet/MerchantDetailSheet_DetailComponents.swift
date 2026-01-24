//
//  MerchantDetailComponents.swift
//  Chur
//
//  Created by Pak Ho on 3/30/26.
//

import SwiftUI

struct CardThumbnailView: View {
    let card: CreditCard?
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        if let card, let uiImage = UIImage(named: card.imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else if let card {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.cardColor(for: card.issuer))
                .frame(width: width, height: height)
                .overlay {
                    Text(card.issuer.prefix(2).uppercased())
                        .font(.system(size: width > 70 ? 22 : 14, weight: .black))
                        .foregroundStyle(.white)
                }
        }
    }
}
