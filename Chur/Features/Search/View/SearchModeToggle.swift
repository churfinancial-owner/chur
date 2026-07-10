//
//  Seach_Map_Toggle.swift
//  Chur
//
//  Created by Pak Ho on 3/12/26.
//

import Foundation
import SwiftUI
import SwiftData
import MapKit

enum SearchMode: String, CaseIterable {
    case map = "Map"
    case online = "Online"
}

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
                        .font(selectedMode == mode ? .churRowText() : .churRowTextMedium())
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


