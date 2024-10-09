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
    TIMESERIES 1 hours
    FACET name
    SINCE 1 day ago
    """
    @State var results: NrdbResults?
    @State var metadata: NrdbMetadata?
    
    var body: some View {
        Button(action: runQuery, label: { Text("Run Query") })
        TextEditor(text: $query)
        GroupBox("Results") {
            if let results = results as? NrdbFacetResults, let metadata = metadata {
                TimeriesChart(data: results.data, metadata: metadata)
            }
        }
    }
    
    func  runQuery() {
        Queries.nrql(query: query, debug: true) { result in
            guard let result = result else { return }
            
            results = result.results
            metadata = result.metadata
        }
    }
}

struct TimeriesChart: View {
    var data: [NrdbFacetResults.Datum]
    var metadata: NrdbMetadata
    
    var body: some View {
        Chart(data) { datum in
            AreaMark(
                x: .value("Timestamp", datum.beginTime),
                y: .value("Count", datum.count)
            )
            .foregroundStyle(by: .value("City", datum.facet))
        }
    }
}

#Preview {
    NRQLEditorView()
}
