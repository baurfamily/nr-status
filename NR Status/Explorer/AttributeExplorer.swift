//
//  AttributeExplorer.swift
//  NR Status
//
//  Created by Eric Baur on 3/16/25.
//

import SwiftUI

struct AttributeExplorer : View {
    let event: String
    @State var attributes: [Attribute] = []

    var attributeTypes: [String] {
        Array(Set(attributes.map(\.type))).sorted()
    }
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(attributeTypes, id: \.self) { typeName in
                    AttributeGroup(title: typeName.capitalized, attributes: $attributes) { $0.type == typeName }
                }
            }
        }
        .navigationTitle("\(event) attributes")
        .navigationViewStyle(.columns)
        .task {
            Queries().nrql(query: "SELECT keyset() FROM \(event)") { results in
                if let results {
                    self.attributes = results.data.map {
                        Attribute(
                            event: event,
                            type: $0.stringFields["type"]!,
                            key: $0.stringFields["key"]!
                        )
                    }
                }
            }
        }
        
    }
}

#Preview {
    AttributeExplorer(event: "Transaction")
}
