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
    SINCE 1 day ago
    COMPARE WITH 2 days ago
    TIMESERIES 6 hours
    """
    @State var resultContainer: NrdbResultContainer?
    
    var body: some View {
        HStack {
            Button(action: runQuery, label: { Text("Run Query") })
            Button(action: getSample, label: { Text("Get Sample") })
        }
        TextEditor(text: $query)
        GroupBox("Results") {
            if let resultContainer {
                if resultContainer.results.isTimeseries {
                    TimeseriesChart(resultsContainer: resultContainer)
                } else {
                    Text("facted, not timeseries data")
                }
            }
        }
    }
    
    func  runQuery() {
        Queries.nrql(query: query, debug: true) { result in
            guard let result = result else { return }
            resultContainer = result
        }
    }
    
    func getSample() {
        if let result = ChartSamples.sampleData(faceted: true, size: .small) {
            resultContainer = result
        } else {
            print("failed to get samples")
        }
        print("uh....")
    }
}

#Preview {
    NRQLEditorView()
}
