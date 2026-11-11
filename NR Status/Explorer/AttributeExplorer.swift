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
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var filterText = ""

    var filteredAttributes: [Attribute] {
        let text = filterText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return attributes }
        return attributes.filter { $0.key.localizedCaseInsensitiveContains(text) }
    }

    var attributeTypes: [String] {
        Array(Set(filteredAttributes.map(\.type))).sorted()
    }
    
    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            } else if attributes.isEmpty {
                Text("No attributes found for \(event) in the last day.")
                    .foregroundStyle(.secondary)
            } else if filteredAttributes.isEmpty {
                Text("No attributes match \"\(filterText)\".")
                    .foregroundStyle(.secondary)
            }
            ForEach(attributeTypes, id: \.self) { typeName in
                AttributeGroupView(title: typeName.capitalized, query: $query, attributes: .constant(filteredAttributes)) { $0.type == typeName }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            TextField("Filter attributes", text: $filterText)
                .textFieldStyle(.roundedBorder)
                .padding(8)
        }
        .navigationTitle("\(event) attributes")
        .task {
            // a bit bass-ackwards of a feedback loop to set the
            // event on the query, but this works for now
            query.event = event
            
            // find the attributes associated with the event
            // same window as the event list, otherwise events without very recent data come back empty
            do {
                if let results = try await Queries().getNrqlData(query: "SELECT keyset() FROM \(event) SINCE 1 day ago") {
                    attributes = Attribute.attributes(event: event, fromKeyset: results)
                }
            } catch {
                errorMessage = "Couldn't load attributes: \(error.localizedDescription)"
            }
            isLoading = false
        }
        
    }
}

#Preview {
    @Previewable @State var query: QueryBuilder = .init(event: "Transaction")
    AttributeExplorer(event: "Transaction", query: $query )
}
