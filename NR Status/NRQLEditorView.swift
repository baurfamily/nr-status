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
    SELECT
        count(*),
        uniqueCount(name)
    FROM Transaction
    COMPARE WITH 1 week ago
    TIMESERIES
    """
    @State var results: NrdbResults?
    @State var metadata: NrdbMetadata?
    
    var body: some View {
        HStack {
            Button(action: runQuery, label: { Text("Run Query") })
            Button(action: saveWidget, label: { Text("Make Widget") })
        }
        TextEditor(text: $query)
        GroupBox("Results") {
            if let results = results, let metadata = metadata {
                if results.isTimeseries {
                    TimeseriesChart(data: results.data, metadata: metadata)
                } else {
                    Text("facted, not timeseries data")
                }
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
    
    func saveWidget() {
        if let result = ChartSamples.sampleData(faceted: true, size: .small) {
            results = result.results
            metadata = result.metadata
        } else {
            print("failed to get samples")
        }
        print("uh....")
    }
}

#Preview {
    NRQLEditorView()
}
