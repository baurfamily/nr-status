//
//  NRQLEditorView.swift
//  NR Status
//
//  Created by Eric Baur on 10/7/24.
//

import SwiftUI
import Charts

struct NRQLEditorView: View {
    @State var query: String = """
        FROM Transaction
        SELECT count(*)
        TIMESERIES 5 minutes
    """
    @State var results: [NrqlFacetResults] = []
    
    var body: some View {
        Button(action: runQuery, label: { Text("Run Query") })
        TextEditor(text: $query)
        GroupBox("Results") {
            TimeriesChart(data: results)
        }
    }
    
    func  runQuery() {
        Queries.nrql(query: query, debug: true) { print($0); results = $0 }
    }
}

struct TimeriesChart: View {
    var data: [NrqlFacetResults]
    
    var body: some View {
        Chart(data) {
            LineMark(
                x: .value("Timestamp", ($0.beginTime)),
                y: .value("Count", $0.count)
            )
        }
    }
}

#Preview {
    NRQLEditorView()
}
