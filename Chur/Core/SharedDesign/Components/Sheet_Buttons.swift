//
//  Sheet_Button.swift
//  Chur
//
//  Created by Pak Ho on 4/28/26.
//

import SwiftUI

struct SheetToolbarButton: View {
    enum ButtonType {
        case cancel
        case done
    }
    
    let type: ButtonType
    let title: String? // Optional: defaults to "Cancel" or "Done"
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title ?? defaultTitle)
                .fontWeight(type == .done ? .bold : .regular)
                .foregroundStyle(type == .done ? Color.churOlive : .red)
                .font(.churRowText())
        }
    }
    
    private var defaultTitle: String {
        switch type {
        case .cancel: return "Cancel"
        case .done: return "Done"
        }
    }
}
