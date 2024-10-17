//
//  ContentView.swift
//  NRQL Editor
//
//  Created by Eric Baur on 10/14/24.
//

import SwiftUI
import CodeEditorView
import LanguageSupport

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    
    @Binding var document: NRQL_EditorDocument
    
    @State var messages: Set<TextLocated<Message>> = Set()
    @State var position = CodeEditor.Position()
    
    var body: some View {
        NavigationSplitView {
            List(document.queries) { docQuery in
                Text(docQuery.query.title)
            }
        } content: {
            CodeEditor(
                text: $document.text,
                position: $document.position,
                messages: $messages,
                language: .nrql(),
                layout: CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: true)
            ).environment(\.codeEditorTheme, (colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)).navigationSplitViewColumnWidth(min: 200, ideal: 500, max: 1000)
        } detail: {
            List(document.queries) { docQuery in
                if let resultContainer = docQuery.query.resultContainer {
                    TimeseriesChart(resultsContainer: resultContainer)
                        .frame(minHeight: 300)
                        .chartLegend(.hidden)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
            }
        }
    }
}


#Preview {
    ContentView(document: .constant(NRQL_EditorDocument()))
}
