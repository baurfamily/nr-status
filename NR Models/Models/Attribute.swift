//
//  Attribute.swift
//  NR Status
//
//  Created by Eric Baur on 3/15/25.
//

import SwiftUI

struct Attribute : Hashable, Identifiable {
    var id: String { self.key }

    let event: String
    let type: String
    let key: String
    
    var isSelected = false
}
