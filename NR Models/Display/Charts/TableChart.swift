//
//  TableChart.swift
//  NR Status
//
//  Created by Eric Baur on 10/26/24.
//

import SwiftUI

struct TableChart : View {
    let resultsContainer: NrdbResultContainer

    var body: some View {
        Table(resultsContainer.data) {
            if resultsContainer.isTimeseries {
                TableColumn("Timestamp") { datum in
                    Text(datum.beginTime!, format: .dateTime)
                }
            }
            TableColumnForEach(resultsContainer.fieldNames, id:\.self) { field in
                TableColumn(field) { datum in
                    if datum.numberFields.keys.contains(field) {
                        Text(datum.numberFields[field] ?? 0, format: .number)
                    } else {
                        Text(datum.stringFields[field] ?? "")
                    }
                }
            }
        }
    }
}

#Preview {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, comparable: false, size: .small) {
        Text("data \(single.results.data.count)")
        TableChart(resultsContainer: single)
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .single, timeseries: false, comparable: false, size: .small))
    }
}
