//
//  AttributeExplorer.swift
//  NR Status
//
//  Created by Eric Baur on 3/16/25.
//

import SwiftUI

struct AttributeExplorer : View {
    let event: String
    
    @Binding var query: QueryBuilder
    @State var attributes: [Attribute] = []

    var attributeTypes: [String] {
        Array(Set(attributes.map(\.type))).sorted()
    }
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(attributeTypes, id: \.self) { typeName in
                    AttributeGroupView(title: typeName.capitalized, query: $query, attributes: $attributes) { $0.type == typeName }
                }
            }
        }
        .navigationTitle("\(event) attributes")
        .navigationViewStyle(.columns)
        .task {
            // a bit bass-ackwards of a feedback loop to set the
            // event on the query, but this works for now
            query.event = event
            
            // find the attributes associated with the event
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
    @Previewable @State var query: QueryBuilder = .init(event: "Transaction")
    AttributeExplorer(event: "Transaction", query: $query )
}
