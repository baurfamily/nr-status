//
//  NrqlViewer.swift
//  NR Status
//
//  Created by Eric Baur on 2/20/25.
//

import SwiftUI
import CodeEditorView

struct NrqlViewer : View {
    @State var document: NRQL_EditorDocument = NRQL_EditorDocument(text:"SELECT COUNT(*) FROM Transaction FACET name")
    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    var body: some View {
        NavigationSplitView {
            CodeEditor(
                text: $document.text,
                position: $document.position,
                messages: $document.messages,
                language: .nrql(),
                layout: CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: true)
            )
            .environment(\.codeEditorTheme, (colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight))
            .frame(minWidth: 300)
        } detail: {
            if let resultContainer = document.focusedResult {
                ConfigurableChartView(resultsContainer: resultContainer)
            } else {
                Text("Hit Command-return to run the focused query...")
                Text("Query count: \(document.queries.count)")
                Text("Focused query: \(document.focusedQueryId ?? "None")")
                Text("Focused results: \(document.focusedResult?.results.data.count ?? -1)")
                Text(document.text)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(\.document, $document)

    }
}
