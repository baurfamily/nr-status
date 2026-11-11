//
//  DocumentView.swift
//  NRQL Editor
//
//  Created by Eric Baur on 10/14/24.
//

import SwiftUI
import CodeEditorView
import LanguageSupport

extension EnvironmentValues {
    @Entry var codeEditorLayoutConfiguration: CodeEditor.LayoutConfiguration = CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: true)
}


struct DocumentView: View {
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @Environment(\.codeEditorLayoutConfiguration) private var codeEditorLayoutConfiguration: CodeEditor.LayoutConfiguration
    
    @Binding var document: NRQL_EditorDocument
    // local state variables removed: use the document's position and focusedQueryId
    
    var body: some View {
        NavigationSplitView {
            CodeEditor(
                text: $document.text,
                position: $document.position,
                messages: $document.messages,
                language: .nrql()
            )
            .environment(\.codeEditorLayoutConfiguration, codeEditorLayoutConfiguration)
            .environment(\.codeEditorTheme, (colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight))
            .navigationSplitViewColumnWidth(min: 200, ideal: 500, max: 1000)
        } detail: {
                ResultsTabView(document: $document)
        }
    }
}

struct ResultsTabView : View {
    @Binding var document: NRQL_EditorDocument
    
    var body: some View {
        if document.queries.isEmpty {
            // Friendly placeholder when there are no queries/results
            VStack {
                Spacer()
                Text("No query results")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Run a query in the editor to see results here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            TabView(selection: $document.focusedQueryId) {
                ForEach(document.queries) { docQuery in
                    Tab(value: docQuery.id) {
                        if let resultContainer = docQuery.query.resultContainer {
                            ConfigurableChartView(resultsContainer: resultContainer)
                        } else {
                            // If a query exists but has no results yet, show placeholder
                            VStack {
                                Spacer()
                                if docQuery.query.isRunning {
                                    ProgressView()
                                } else if let errorMessage = docQuery.query.errorMessage {
                                    Text("The query failed")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text(errorMessage)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No results for this query")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}


#Preview {
    DocumentView(document: .constant(NRQL_EditorDocument()))
}
