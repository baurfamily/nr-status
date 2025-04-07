//
//  EventExplorer.swift
//  NR Status
//
//  Created by Eric Baur on 3/16/25.
//

import SwiftUI

struct EventExplorer : View {
    @Binding var query: QueryBuilder
    
    @State var events: [String] = []
    @State var eventFilter: String = ""
    
    var filteredEvents: [String] {
        guard !eventFilter.isEmpty else { return events }
        let filter = eventFilter.lowercased()
        return events.filter { $0.lowercased().contains(filter) }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredEvents, id: \.self) { event in
                NavigationLink(event, value: event)
            }
            .navigationDestination(for: String.self) {
                AttributeExplorer(event: $0, query: $query)
            }
            .navigationDestination(for: Attribute.self) {
                AttributeSummaryActionsView(attribute: $0, query: $query)
            }
        }
        .navigationViewStyle(.columns)
        .navigationTitle("Events")
        .task {
            Queries().nrql(query: "SHOW EVENT TYPES since 1 day ago") { results in
                if let results {
                    events = results.data.map { $0.stringFields["eventType"] ?? "" }
                }
            }
        }.searchable(text: $eventFilter, placement: .sidebar)
    }
}

#Preview {
    @Previewable @State var query: QueryBuilder = .init(event: "Transaction")
    EventExplorer(query: $query)
}
