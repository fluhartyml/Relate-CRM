//
//  Item.swift
//  Relate CRM
//
//  Created by Michael Fluharty on 12/2/25.
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
