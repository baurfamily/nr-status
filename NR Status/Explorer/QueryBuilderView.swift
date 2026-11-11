//
//  QueryBuilderView.swift
//  NR Status
//
//  Created by Eric Baur on 3/08/25.
//

import SwiftUI
import CodeEditorView

struct QueryBuilderView : View {
    @State var query = NrqlQuery(from: "SELECT COUNT(*) FROM Transaction FACET name")
    @State var queryBuilder: QueryBuilder = .init(event: "")
    @State private var selectedEvent: String?
    
    @State var chartConfiguration: ChartConfiguration = ChartConfiguration(resultContainer: NrdbResultContainer.empty)

    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    
    var body: some View {
        NavigationSplitView {
            EventExplorer(selection: $selectedEvent)
        } content: {
            Group {
                if let selectedEvent {
                    NavigationStack {
                        AttributeExplorer(event: selectedEvent, query: $queryBuilder)
                            .navigationDestination(for: Attribute.self) {
                                AttributeSummaryActionsView(attribute: $0, query: $queryBuilder)
                            }
                    }
                    .id(selectedEvent)
                } else {
                    Text("Select an event").foregroundStyle(.secondary)
                }
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 380, max: 700)
        } detail: {
            ConfigurableChartView(config: chartConfiguration)
                .inspectorHeader {
                    QueryTextView(nrql: queryBuilder.formattedNrql)
                }
                .overlay {
                    if query.isRunning {
                        ProgressView()
                    }
                }
                .toolbar {
                    ToolbarItemGroup {
                        TimePicker(query: $queryBuilder)
                            .fixedSize()
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(\.query, $query)
        .onChange(of: $queryBuilder.wrappedValue) {
            let newQuery = NrqlQuery(from: queryBuilder.nrql)
            query = newQuery
            Task {
                await newQuery.getData()
                // the builder may have changed again while this was running
                guard query === newQuery, let results = newQuery.resultContainer else { return }
                chartConfiguration.updateResults(results)
            }
        }
    }
}

#Preview {
    QueryBuilderView()
}
