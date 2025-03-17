//
//  NrqlExplorer.swift
//  NR Status
//
//  Created by Eric Baur on 3/08/25.
//

import SwiftUI
import CodeEditorView

struct NrqlExplorer : View {
    @State var query = NrqlQuery(from: "SELECT COUNT(*) FROM Transaction FACET name")
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    
    @State var chartConfiguration: ChartConfiguration = ChartConfiguration(resultContainer: NrdbResultContainer.empty)

    var body: some View {
        NavigationSplitView {
            EventExplorer(query: $query)
        } detail: {
            if query.running {
                ProgressView()
            }
            VStack {
                Text(query.text)
                ConfigurableChartView(config: chartConfiguration)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(\.query, $query)
        .onChange(of: $query.wrappedValue) {
            print("updated query")
            query.runQuery() { results in
                guard let results else { return }
                print("updating config")
                chartConfiguration.updateResults(results)
            }
            if let resultContainer = query.resultContainer {
                chartConfiguration.updateResults(resultContainer)
            }
        }
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
