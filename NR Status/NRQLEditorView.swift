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
    @State var selectedDate: Date?
    @State var selectedDateRange: ClosedRange<Date>?
    
    var body: some View {
        GroupBox {
            HStack {
                Toggle("Stacked", isOn: $isStacked).toggleStyle(.switch)
            }
        }
//        if selectedDate {
//            GroupBox {
//                
//            }
//        }
        Chart(data) { datum in
            if let selectedDateRange {
                RectangleMark(
                    xStart: .value("Start", selectedDateRange.lowerBound, unit: .minute),
                    xEnd: .value("End", selectedDateRange.upperBound, unit: .minute)
                )
                .foregroundStyle(.gray.opacity(0.03 ))
                .zIndex(-2)
                .annotation(
                    position: .topLeading, spacing: 0,
                    overflowResolution: .init(
                        x: .fit(to: .chart),
                        y: .disabled
                    )
                ){ Text( "bar" ) }
            }
            if let selectedDate {
                RuleMark(
                    x: .value("Selected", selectedDate, unit: .minute)
                )
                .zIndex(-1)
                .annotation(
                    position: .topLeading, spacing: 0,
                    overflowResolution: .init(
                        x: .fit(to: .chart),
                        y: .disabled
                    )
                ){ Text( "foo" ) }
            }
            if isStacked {
                AreaMark(
                    x: .value("Timestamp", datum.beginTime!),
                    y: .value("Count", datum.numberFields["count"]!)
                )
                .foregroundStyle(by: .value("Facet", (datum.facet ?? "Count")))
                .symbol(by: .value("Facet", (datum.facet ?? "Count")))
                .interpolationMethod(.catmullRom)
                
            } else {
                LineMark(
                    x: .value("Timestamp", datum.beginTime!),
                    y: .value("Count", datum.numberFields["count"]!)
                )
                .foregroundStyle(by: .value("Facet", (datum.facet ?? "Count")))
                .symbol(by: .value("Facet", (datum.facet ?? "Count")))
                .interpolationMethod(.catmullRom)
                
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXSelection(range: $selectedDateRange)
    }
}

#Preview {
    NRQLEditorView()
}
