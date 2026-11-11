//
//  TableChart.swift
//  NR Status
//
//  Created by Eric Baur on 10/26/24.
//

import SwiftUI

struct TableChart : View {
    var config: ChartConfiguration
    
    var resultContainer: NrdbResultContainer {
        config.resultContainer
    }
    
    func value(for field: String, in datum: NrdbResults.Datum) -> String {
        var result: String
        
        if datum.numberFields.keys.contains(field) {
            result = String(datum.numberFields[field] ?? 0)
        } else {
            result = String(datum.stringFields[field] ?? "")
        }
        
        return result
    }
    
    // row ids are positional: event timestamps (and other derived ids) can repeat,
    // and duplicate ids crash Table
    private struct Row : Identifiable {
        let id: Int
        let datum: NrdbResults.Datum
    }
    
    private var rows: [Row] {
        resultContainer.data.enumerated().map { Row(id: $0.offset, datum: $0.element) }
    }
    
    var body: some View {
        // the column set varies with the query; rebuild the table when it changes
        Table(rows) {
            if resultContainer.isTimeseries || resultContainer.isEvents {
                TableColumn("Timestamp") { (row: Row) in
                    if let date = row.datum.date {
                        Text(date, style: .relative)
                    }
                }
            }
            TableColumnForEach(resultContainer.fieldNames, id:\.self) { field in
                TableColumn(field) { (row: Row) in
                    Text(value(for: field, in: row.datum))
                }
            }
        }
        .id(resultContainer.fieldNames)
    }
}

#Preview("Event data") {
    if let single = ChartSamples.sampleData(facet: .none, timeseries: false, comparable: false, size: .large) {
        Text("data \(single.results.data.count)")
        TableChart(config: .init(resultContainer: single))
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .none, timeseries: false, comparable: false, size: .large))
    }
}

#Preview("Single Facet") {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, comparable: false, size: .small) {
        Text("data \(single.results.data.count)")
        TableChart(config: .init(resultContainer: single))
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .single, timeseries: false, comparable: false, size: .small))
    }
}
