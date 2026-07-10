import SwiftUI

// MARK: - Earning Rate Row

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
            CategoryIconView(category: category, font: .system(size: 24))
                .frame(width: 44, height: 44)
                .background(Color.churOffWhite)
                .clipShape(Circle())
            
            Text(category.displayName)
                .font(.churSectionHeader())
                .foregroundStyle(Color.churDarkGray)
            
            Spacer()
            
            Text(rate.formatAsRate())
                .font(.churBigTitle4())
                .foregroundStyle(numberColor)
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    let isEditable: Bool
    var onEdit: (() -> Void)? = nil
    
    var body: some View {
        Button {
            if isEditable { onEdit?() }
        } label: {
            HStack {
                Text(label)
                    .font(.churRowTextMedium())
                    .foregroundStyle(Color.churDarkGray)
                
                Spacer()
                
                Text(value)
                    .font(.churRowTextMedium())
                    .foregroundStyle(Color.churMediumGray)
                
                if isEditable {
                    Image(systemName: "chevron.right")
                        .font(.churSmallBold())
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

// MARK: - Shared Section Components

struct CardSectionHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.churSmallBold())
                .foregroundStyle(Color.churOlive)
                .tracking(1.0)
                .padding([.horizontal, .top], 20)
                .padding(.bottom, 12)
            Divider().padding(.horizontal, 20)
        }
    }
}

struct CardRowDivider: View {
    var body: some View {
        Divider().padding(.horizontal, 4).opacity(0.4)
    }
}
