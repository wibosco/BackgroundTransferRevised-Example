//
//  GridItem+Layout.swift
//  BackgroundTransfer-Example
//
//  Created by William Boles on 11/03/2025.
//

import Foundation
import SwiftUI

extension GridItem {
    
    static func threeFlexibleColumns() -> [GridItem] {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ]
        
        return columns
    }
}
