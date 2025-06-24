//
//  Item.swift
//  TamStar
//
//  Created by Melusine on 2025/6/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
