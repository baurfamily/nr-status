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
    SINCE 1 day ago
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
        print("uh....")
    }
}

struct TimeseriesChart: View {
    var data: [NrdbResults.Datum]
    var metadata: NrdbMetadata
    
    @State var isStacked: Bool = false
    
    var body: some View {
        GroupBox {
            HStack {
                Toggle("Stacked", isOn: $isStacked).toggleStyle(.switch)
            }
        }
        Chart(data) { datum in
            if isStacked {
                AreaMark(
                    x: .value("Timestamp", datum.beginTime!),
                    y: .value("Count", datum.count)
                )
                .foregroundStyle(by: .value("Facet", (datum.facet ?? "Count")))
            } else {
                LineMark(
                    x: .value("Timestamp", datum.beginTime!),
                    y: .value("Count", datum.count)
                )
                .foregroundStyle(by: .value("Facet", (datum.facet ?? "Count")))
            }
        }
    }
}

#Preview {
    NRQLEditorView()
}
