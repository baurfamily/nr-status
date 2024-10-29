//
//  TableChart.swift
//  NR Status
//
//  Created by Eric Baur on 10/26/24.
//

import SwiftUI

struct TableChart : View {
    @State var resultsContainer: NrdbResultContainer

    var body: some View {
        Text("TableChart")
        // doesn't like binding to our convinience accessor since it's a
        // read-only calculated property
        List($resultsContainer.results.data) { datum in
            HStack {
                ForEach(resultsContainer.fieldNames, id:\.self) { field in
                    if datum.numberFields.wrappedValue.keys.contains(field) {
                        Text(datum.numberFields[field].wrappedValue ?? 0, format: .number)
                    } else {
                        Text(datum.stringFields[field].wrappedValue ?? "")
                    }
                }
                Text("hi")
            }
           Text("asdf")
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
