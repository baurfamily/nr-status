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
    @State var queryBuilder: QueryBuilder = .init(event: "")
    
    @State var chartConfiguration: ChartConfiguration = ChartConfiguration(resultContainer: NrdbResultContainer.empty)

    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    
    var body: some View {
        NavigationSplitView {
            EventExplorer(query: $queryBuilder)
        } detail: {
            if query.isRunning {
                ProgressView()
            }
            VStack {
                HStack {
                    TimePicker(query: $queryBuilder)
                    Text(queryBuilder.nrql)
                        .textSelection(.enabled)
                }
                ConfigurableChartView(config: chartConfiguration)
                    .frame(maxHeight: .infinity)
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
    NrqlExplorer()
}
