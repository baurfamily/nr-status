//
//  EventExplorer.swift
//  NR Status
//
//  Created by Eric Baur on 3/16/25.
//

import SwiftUI

struct EventExplorer : View {
    @Binding var selection: String?
    
    @State var events: [String] = []
    @State var eventFilter: String = ""
    
    var filteredEvents: [String] {
        guard !eventFilter.isEmpty else { return events }
        let filter = eventFilter.lowercased()
        return events.filter { $0.lowercased().contains(filter) }
    }
    
    var body: some View {
        List(filteredEvents, id: \.self, selection: $selection) { event in
            Text(event)
        }
        .navigationTitle("Events")
        .task {
            if let results = try? await Queries().getNrqlData(query: "SHOW EVENT TYPES since 1 day ago") {
                events = results.data.map { $0.stringFields["eventType"] ?? "" }
            }
        }.searchable(text: $eventFilter, placement: .sidebar)
    }
}

#Preview {
    @Previewable @State var selection: String?
    EventExplorer(selection: $selection)
}
