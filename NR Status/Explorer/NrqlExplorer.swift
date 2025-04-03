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
            if query.running {
                ProgressView()
            }
            VStack {
                Text(queryBuilder.nrql)
                ConfigurableChartView(config: chartConfiguration)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(\.query, $query)
        .onChange(of: $queryBuilder.wrappedValue) {
            query = .init(from: queryBuilder.nrql)
            query.runQuery() { results in
                guard let results else { return }
                chartConfiguration.updateResults(results)
            }
        }
    }
}

#Preview {
    NrqlExplorer()
}
