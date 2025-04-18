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
    
    var body: some View {
        Table(resultContainer.data) {
            if resultContainer.isTimeseries || resultContainer.isEvents {
                TableColumn("Timestamp") { (datum: NrdbResults.Datum) in
                    Text(datum.date, style: .relative)
                }
            }
            TableColumnForEach(resultContainer.fieldNames, id:\.self) { field in
                TableColumn(field) { datum in
                    Text(value(for: field, in: datum))
                }
            }
        }
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
