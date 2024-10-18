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
            Text("Maybe metadata...")
        } content: {
            CodeEditor(
                text: $document.text,
                position: $document.position,
                messages: $messages,
                language: .nrql(),
                layout: CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: true)
            ).environment(\.codeEditorTheme, (colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)).navigationSplitViewColumnWidth(min: 200, ideal: 500, max: 1000)
        } detail: {
            HStack {
                ResultsList(document: $document)
                ResultsTabView(document: $document)
            }
        }
    }
}

struct ResultsList : View {
    @Binding var document: NRQL_EditorDocument
    
    var body: some View {
        List(document.queries) { docQuery in
            if let resultContainer = docQuery.query.resultContainer {
                VStack {
                    Text(docQuery.query.title).font(.title)
                    TimeseriesChart(resultsContainer: resultContainer)
                        .frame(minHeight: 300)
                        .chartLegend(.hidden)
                }
            } else {
                if docQuery.focused {
                    HStack {
                        Text(docQuery.query.title)
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                } else {
                    HStack {
                        Text(docQuery.query.title)
                        Image(systemName: "questionmark.circle.fill")
                    }
                }
            }
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
                            TimeseriesChart(resultsContainer: resultContainer)
                            .frame(minHeight: 300)
                    } else {
                        if docQuery.focused {
                            HStack {
                                Text(docQuery.query.title)
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                        } else {
                            HStack {
                                Text(docQuery.query.title)
                                Image(systemName: "questionmark.circle.fill")
                            }
                        }
                    }
                }
            }
        }
    }
}


#Preview {
    ContentView(document: .constant(NRQL_EditorDocument()))
}
