//
//  AttributeDetail.swift
//  NR Status
//
//  Created by Eric Baur on 3/16/25.
//

import SwiftUI

struct AttributeDetail : View {
    let attribute: Attribute
    
    var body: some View {
        ScrollView {
            VStack {
                Text("detail view...")
                Text(attribute.key)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    AttributeDetail(attribute: .init(
        event: "Test Event",
        type: "numeric",
        key: "test"
    ))
}
