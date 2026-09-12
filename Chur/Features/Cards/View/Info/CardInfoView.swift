import SwiftUI

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

