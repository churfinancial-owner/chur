import SwiftUI

// MARK: - Earning Rate Row (Refined Style)
struct EarningRateRow: View {
    let category: SpendingCategory
    let rate: Double
    
    var numberColor: Color {
        if rate >= 4.0 {
            return .churOlive
        } else if rate >= 2.0 {
            return .churMediumGray
        } else {
            return .churLightGray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            CategoryIconView(category: category, font: .system(size: 24))
                .frame(width: 44, height: 44)
                .background(Color.churOffWhite)
                .clipShape(Circle())
            
            // Category name
            Text(category.displayName)
                .font(.churSectionHeader())
                .foregroundStyle(Color.churDarkGray)
            
            Spacer()
            
            // Rate
            Text(rate.formatAsRate())
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(numberColor)
        }
    }
}

// MARK: - Detail Row Component
struct DetailRow: View {
    let label: String
    let value: String
    let isEditable: Bool
    var onEdit: (() -> Void)? = nil
    
    var body: some View {
        Button {
            if isEditable {
                onEdit?()
            }
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.churDarkGray)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.churMediumGray)
                
                if isEditable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.churMediumGray)
                        .padding(.leading, 4)
                }
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .disabled(!isEditable)
    }
}
