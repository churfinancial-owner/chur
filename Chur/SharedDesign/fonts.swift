//
//  fonts.swift
//  Chur
//
//  Created by Pak Ho on 1/17/26.
//
// Row Texts: .font(.churRowText())
// Bubble Texts:  .font(.churRowText())

import SwiftUI

extension Font {
    // MARK: - Chur Rounded Fonts
    
    static func churBigTitle() -> Font {
        .system(size: 58, weight: .bold, design: .rounded)
    }
    
    static func churBigTitle1() -> Font {
        .system(size: 48, weight: .bold, design: .rounded)
    }
    
    static func churBigTitle2() -> Font {
        .system(size: 38, weight: .bold, design: .rounded)
    }
    
    static func churBigTitle3() -> Font {
        .system(size: 32, weight: .bold, design: .rounded)
    }
    
    static func churBigTitle4() -> Font {
        .system(size: 20, weight: .bold, design: .rounded)
    }

    
    static func churTitle() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }
    
    static func churTitle2() -> Font {
        .system(size: 24, weight: .bold, design: .rounded)
    }
    
    static func churHeadline() -> Font {
        .system(size: 18, weight: .bold, design: .rounded)
    }
    
    static func churSubheadline() -> Font {
        .system(size: 16, weight: .medium, design: .rounded)
    }
    
    static func churBody() -> Font {
        .system(size: 16, weight: .regular, design: .rounded)
    }
    
    // MARK: - Row & Bubble Texts
    static func churRowText() -> Font {
        .system(size: 15, weight: .bold, design: .rounded)
    }
    
    static func churRowTextRegular() -> Font {
        .system(size: 15, weight: .regular, design: .rounded)
    }
    
    // MARK: - Captions & Footnotes
    static func churCaption() -> Font {
        .system(size: 14, weight: .bold, design: .rounded)
    }
    
    static func churCaptionRegular() -> Font {
        .system(size: 14, weight: .regular, design: .rounded)
    }
    
    static func churFootnote() -> Font {
        .system(size: 13, weight: .regular, design: .rounded)
    }
    
    static func churFootnoteBold() -> Font {
        .system(size: 13, weight: .bold, design: .rounded)
    }
    
    static func churSmall() -> Font {
        .system(size: 12, weight: .regular, design: .rounded)
    }
    
    static func churSmallBold() -> Font {
        .system(size: 12, weight: .bold, design: .rounded)
    }
    
    static func churSectionHeader() -> Font {
        .system(size: 16, weight: .bold, design: .rounded)
    }
    
    // MARK: - Hero Headers
    static func churHero() -> Font {
        .system(size: 38, weight: .bold, design: .rounded)
    }
    
    // MARK: - Medium Weight Variants
    static func churHeadlineMedium() -> Font {
        .system(size: 18, weight: .medium, design: .rounded)
    }
    
    static func churImageMedium() -> Font {
        .system(size: 16, weight: .black)
    }
    
    static func churRowTextMedium() -> Font {
        .system(size: 15, weight: .medium, design: .rounded)
    }
    
    static func churCaptionMedium() -> Font {
        .system(size: 14, weight: .medium, design: .rounded)
    }
    
    static func churFootnoteMedium() -> Font {
        .system(size: 13, weight: .medium, design: .rounded)
    }
    
    
    
    // MARK: - Micro Labels (Size 11)
    static func churMicro() -> Font {
        .system(size: 11, weight: .regular, design: .rounded)
    }
    
    static func churMicroMedium() -> Font {
        .system(size: 11, weight: .medium, design: .rounded)
    }
    
    static func churMicroBold() -> Font {
        .system(size: 11, weight: .bold, design: .rounded)
    }
    
    // MARK: - Badges & Tiny UI (Size 10)
    static func churBadge() -> Font {
        .system(size: 10, weight: .regular, design: .rounded)
    }
    
    static func churBadgeMedium() -> Font {
        .system(size: 10, weight: .medium, design: .rounded)
    }
    
    static func churBadgeBold() -> Font {
        .system(size: 10, weight: .bold, design: .rounded)
    }
    
}
