//
//  ArrayExtension.swift
//  iOS
//
//  Created by Pavel Nosov on 11/24/17.
//  Copyright © 2017 MBIENTLAB, INC. All rights reserved.
//

import UIKit

extension Array where Element: Numeric {
    /// Returns the total sum of all elements in the array
    var total: Element { return reduce(0, +) }
}

extension Array where Element: BinaryInteger {
    /// Returns the average of all elements in the array
    var average: Double {
        return isEmpty ? 0 : Double(Int(total)) / Double(count)
    }
}

extension Array where Element: FloatingPoint {
    /// Returns the average of all elements in the array
    var average: Element {
        return isEmpty ? 0 : total / Element(count)
    }
}
