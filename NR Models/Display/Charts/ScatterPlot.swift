//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI
import Charts

struct ScatterPlot: View {
    let config: ChartConfiguration
    
    var resultContainer: NrdbResultContainer {
        config.resultContainer
    }

    var data: [NrdbResults.Datum] { config.resultContainer.results.data }
    var metadata: NrdbMetadata { config.resultContainer.metadata }
    
    var selectedFacets: [String] { config.facets.selected }
    var selectedFields: [String] { config.selectedFields }
    
    var xField: String { config.plot.xField ?? ""}
    var yField: String { config.plot.yField ?? ""}
    var sizeField: String? { config.plot.sizeField }

    func seriesNames(for field: String, in datum: NrdbResults.Datum ) -> (String,String) {
        let prefix = datum.isComparable ? "\(datum.comparison): " : ""
        let facetPrefix = datum.isFaceted ? "Facet" : "Data"
        
        let groupName = facetPrefix
        let fieldName: String
        if let facet = datum.facet {
            fieldName = "\(prefix)\(facet)(\(field))"
        } else {
            fieldName = "\(prefix)\(field)"
        }
        
        return (groupName, fieldName)
    }
    
    var body: some View {
        Chart(data.filter { $0.facet == nil || selectedFacets.contains($0.facet!)}) { datum in
            let seriesNames = seriesNames(for: xField, in: datum)

            PointMark(
                x: .value(xField, datum.numberFields[xField] ?? 0),
                y: .value(yField, datum.numberFields[yField] ?? 0)
            )
//            .symbol(by: .value(seriesNames.0, seriesNames.1))
            .foregroundStyle(by: .value(seriesNames.0, seriesNames.1))
            .symbolSize(config.timeseries.showDataPoints ? 50 : 50)
        }
    }
}

// got some thinking to do on how to support comparables
//#Preview("Timeseries comparable (small)") {
//    if let single = ChartSamples.sampleData(comparable: true, size: .small) {
//        ScatterPlot(config: ChartConfiguration(resultContainer: single))
//    
//    } else {
//        Text("No sample data")
//    }
//}

#Preview("Timeseries (medium)") {
    if let single = ChartSamples.sampleData(facet: .single, size: .medium) {
        ScatterPlot(config: ChartConfiguration(resultContainer: single))
    } else {
        Text("No sample data")
    }
}

#Preview("Timeseries (large)") {
    if let single = ChartSamples.sampleData(facet: .single, size: .large) {
        ScatterPlot(config: ChartConfiguration(resultContainer: single))
    } else {
        Text("No sample data")
    }
}
