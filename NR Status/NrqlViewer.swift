//
//  NrqlViewer.swift
//  NR Status
//
//  Created by Eric Baur on 2/20/25.
//

import SwiftUI
import CodeEditorView

//protocol QueryView : View {
//    var query: NrqlQuery { get }
//    mutating func updateQuery(_ query: NrqlQuery)
//    mutating func runQuery()
//}

struct NrqlViewer : View {
    @State var query = NrqlQuery(from: "SELECT COUNT(*) FROM Transaction FACET name")
    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    var body: some View {
        NavigationSplitView {
            CodeEditor(
                text: $query.text,
                position: $query.position,
                messages: $query.messages,
                language: .nrql(),
                layout: CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: true)
            )
            .environment(\.codeEditorTheme, (colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight))
            .frame(minWidth: 300)
        } detail: {
            Button("Run query...") {
//                query.resultContainer = nil
                Task.detached {
                    await query.getData()
                }
                //                query.runQuery() { result in
//                    query.resultContainer = result
//                }
            }
            if let resultContainer = query.resultContainer {
                ConfigurableChartView(resultsContainer: resultContainer)
            } else {
                Text("Hit Command-return to run the focused query...")
                Text(query.text)
//                Text("resolved: \(query.resultContainer != nil)")
            }
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(\.query, $query)
    }
}
