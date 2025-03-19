//
//  AttributeDetail.swift
//  NR Status
//
//  Created by Eric Baur on 3/16/25.
//

import SwiftUI

struct AttributeDetail : View {
    let attribute: Attribute
    @State var summary: AttributeSummary?
    
    var body: some View {
        VStack {
            if let summary {
                AttributeSummaryView(summary: summary)
            }
        }.task {
            print("detail view for \(attribute.key)")
            Task {
                self.summary = await AttributeSummary.generate(from: attribute)
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
