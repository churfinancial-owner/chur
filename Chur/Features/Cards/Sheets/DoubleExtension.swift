//
//  DoubleExtension.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import Foundation

extension Double {
    func formatAsRate() -> String {
        return self.formatted(.number.precision(.fractionLength(0...2))) + "x"
    }
}
