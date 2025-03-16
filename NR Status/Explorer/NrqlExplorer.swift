//
//  NrqlExplorer.swift
//  NR Status
//
//  Created by Eric Baur on 3/08/25.
//

import SwiftUI
import CodeEditorView

//protocol QueryView : View {
//    var query: NrqlQuery { get }
//    mutating func updateQuery(_ query: NrqlQuery)
//    mutating func runQuery()
//}

struct NrqlExplorer : View {
    @State var query = NrqlQuery(from: "SELECT COUNT(*) FROM Transaction FACET name")
    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    var body: some View {
        NavigationSplitView {
            NrqlBuilder(query: $query)
        } detail: {
            Button("Run query...") {
                query.invalidated = true
                Task.detached {
                    await query.getData()
                }
            }
            if query.running {
                ProgressView()
            }
            if let resultContainer = query.resultContainer {
                ConfigurableChartView(resultsContainer: resultContainer)
            } else {
                Text("Hit Command-return to run the focused query...")
                Text(query.text)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(\.query, $query)
    }
}

struct QueryBuilder {
    var event: String
    var attributes: [Attribute] = []
    var facets: [Attribute] = []
    var predicates: [String] = []
    var timeseries: Bool = false
    var timeseriesSize: String?
    
    var nrql: String {
        var query = "FROM \(event) SELECT "
        if !attributes.isEmpty {
            query += attributes.map(\.key).joined(separator: ", ")
        }
        if !facets.isEmpty {
            query += " FACET " + facets.map(\.key).joined(separator: ", ")
        }
        
        // need to figure out how to do aggrecates before this will work
        if timeseries {
            query += " TIMESERIES " + (timeseriesSize ?? "")
        }
        
        return query
    }
}

struct NrqlBuilder : View {
    @Binding var query: NrqlQuery
    
    @State var selectedEvent: String?
    @State var events: [String] = []
    
    @State var selectedAttribute: Set<Attribute> = []
    @State var attributes: [Attribute] = []
    
    @State var queryBuilder: QueryBuilder?
    
    var body: some View {
        Form {
            Picker("Event", selection: $selectedEvent) {
                ForEach(events, id: \.self) { event in
                    Text(event).tag(event)
                }
            }.onChange(of: selectedEvent, initial: false) { _, newEvent in
                if let newEvent {
                    queryBuilder = QueryBuilder(event: newEvent)
                    if let queryBuilder {
                        query = NrqlQuery(from: queryBuilder.nrql)
                    }
                    
                    
                    Queries().nrql(query: "SELECT keyset() FROM \(newEvent)") { results in
                        if let results {
                            attributes = results.data.map {
                                Attribute(
                                    event: newEvent,
                                    type: $0.stringFields["type"]!,
                                    key: $0.stringFields["key"]!
                                )
                            }
                        }
                    }
                }
            }
            ScrollView {
                AttributeSelector(attributes: $attributes).onChange(of: attributes) { _, newAttributes in
                    if queryBuilder != nil {
                        queryBuilder!.attributes = newAttributes.filter(\.isSelected)
                        query = NrqlQuery(from: queryBuilder!.nrql, run: true)
                    }
                }
            }
        }
        .task {
            Queries().nrql(query: "SHOW EVENT TYPES since 1 day ago") { results in
                if let results {
                    events = results.data.map { $0.stringFields["eventType"] ?? "" }
                }
            }
        }
    }
}


#Preview {
    NrqlExplorer()
}
