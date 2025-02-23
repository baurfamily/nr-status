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
            ).environment(\.codeEditorTheme, (colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)).navigationSplitViewColumnWidth(min: 200, ideal: 500, max: 1000)        } content: {

        } detail: {
            HStack {
                ResultsTabView(document: $document)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    Text(docQuery.query.title)
                    if resultContainer.isTimeseries {
                        TimeseriesChart(config: ChartConfiguration(resultContainer: resultContainer))
                            .frame(minHeight: 25)
                            .chartLegend(.hidden)
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                    } else {
                        PieChart(config: .init(resultContainer: resultContainer))
                        BarChart(config: .init(resultContainer: resultContainer))
                    }
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
                        ConfigurableChartView(resultsContainer: resultContainer)
                    }
                }
            }
        }
    }
}


#Preview {
    DocumentView(document: .constant(NRQL_EditorDocument()))
}
