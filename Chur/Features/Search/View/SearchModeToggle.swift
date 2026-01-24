//
//  Seach_Map_Toggle.swift
//  Chur
//
//  Created by Pak Ho on 3/12/26.
//

import SwiftUI
import SwiftData
import MapKit

struct SearchModeToggle: View {
    @Binding var selectedMode: SearchMode
    @Namespace private var toggleNamespace
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(SearchMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { selectedMode = mode }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 15, weight: selectedMode == mode ? .bold : .medium, design: .rounded))
                        .foregroundStyle(selectedMode == mode ? .white : Color.churDarkGray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background {
                            if selectedMode == mode {
                                Capsule()
                                    .fill(Color.churOlive)
                                    .matchedGeometryEffect(id: "toggle", in: toggleNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color(.systemGray6)))
    }
}


