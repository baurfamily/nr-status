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
            if resultContainer.isTimeseries {
                TableColumn("Timestamp") { datum in
                    if let beginTime = datum.beginTime {
                        Text(beginTime, format: .dateTime)
                    } else {
                        Text("")
                    }
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

#Preview {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, comparable: false, size: .small) {
        Text("data \(single.results.data.count)")
        TableChart(config: .init(resultContainer: single))
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .single, timeseries: false, comparable: false, size: .small))
    }
}
