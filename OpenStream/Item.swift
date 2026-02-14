//
//  Item.swift
//  OpenStream
//
//  Created by Ome Asraf on 2/14/26.
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
