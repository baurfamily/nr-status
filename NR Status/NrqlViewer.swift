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
    @Environment(\.codeEditorLayoutConfiguration) private var layoutConfiguration: CodeEditor.LayoutConfiguration


    var body: some View {
        NavigationSplitView {
            CodeEditor(
                text: $query.text,
                position: $query.position,
                messages: $query.messages,
                language: .nrql()
            )
            .environment(\.codeEditorLayoutConfiguration, layoutConfiguration)
            .environment(\.codeEditorTheme, (colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight))
            .frame(minWidth: 300)
        } detail: {
            Button("Run query...") {
                query.run()
            }
            if query.isRunning {
                ProgressView()
            }
            if let resultContainer = query.resultContainer {
                ConfigurableChartView(resultsContainer: resultContainer)
            } else if let errorMessage = query.errorMessage {
                Text("The query failed")
                    .font(.headline)
                Text(errorMessage)
                    .foregroundColor(.secondary)
            } else if !query.isRunning {
                Text("Hit Command-return to run the focused query...")
                Text(query.text)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(\.query, $query)
    }
}

#Preview {
    NrqlViewer()
}
