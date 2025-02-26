//
//  ContentView.swift
//  NRQL Editor
//
//  Created by Eric Baur on 10/14/24.
//

import SwiftUI
import CodeEditorView
import LanguageSupport

struct DocumentView: View {
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    
    @Binding var document: NRQL_EditorDocument
    @State var position = CodeEditor.Position()
    @State var selectedQueryId: Int?
    
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
            .navigationSplitViewColumnWidth(min: 200, ideal: 500, max: 1000)
        } detail: {
                ResultsTabView(document: $document)
        }
    }
}

struct ResultsTabView : View {
    @Binding var document: NRQL_EditorDocument
    
    var body: some View {
        TabView(selection: $document.focusedQueryId) {
            ForEach(document.queries) { docQuery in
                Tab(value: docQuery.id) {
                    if let resultContainer = docQuery.query.resultContainer {
                        ConfigurableChartView(resultsContainer: resultContainer)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


#Preview {
    DocumentView(document: .constant(NRQL_EditorDocument()))
}
