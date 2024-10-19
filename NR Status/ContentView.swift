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
    @State var position = CodeEditor.Position()
    @State var selectedQueryId: Int?
    
    var body: some View {
        NavigationSplitView {
//            ResultsList(queries: $document.queries, selectedQueryId: $selectedQueryId)
            ResultsList(document: $document)
        } content: {
            CodeEditor(
                text: $document.text,
                position: $document.position,
                messages: $document.messages,
                language: .nrql(),
                layout: CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: true)
            ).environment(\.codeEditorTheme, (colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)).navigationSplitViewColumnWidth(min: 200, ideal: 500, max: 1000)
        } detail: {
            HStack {
                ResultsTabView(document: $document)
            }
        }
    }
}

struct ResultsList : View {
//    @Binding var queries: [DocumentQuery]
//    @Binding var selectedQueryId: Int?
    @Binding var document: NRQL_EditorDocument
    
    var body: some View {
        List(document.queries) { docQuery in
            if let resultContainer = docQuery.query.resultContainer {
                HStack {
                    Text(docQuery.query.title).font(.title)
                    TimeseriesChart(resultsContainer: resultContainer)
                        .frame(width: 50, height: 50)
                        .chartLegend(.hidden)
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
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
        }.animation(.easeInOut(duration: 10), value:($document.wrappedValue.focusedQueryId ?? "0"))
            .transition(.slide)
    }
}


#Preview {
    ContentView(document: .constant(NRQL_EditorDocument()))
}
