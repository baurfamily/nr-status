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

#Preview {
    NrqlExplorer()
}
