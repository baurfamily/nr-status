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
    
    var data: [NrdbResults.StatDatum] = []
    var filteredData: [NrdbResults.StatDatum] {
        data.filter { selectedFacets.contains($0.facet) }
    }
    
    init(config: ChartConfiguration) {
        self.config = config
        
        let allData = config.resultContainer.results.data
        
        self.data = allData.map { datum in
            NrdbResults.StatDatum(
                facet: (datum.facet ?? ""),
                x: datum.numberFields[xField] ?? 0,
                y: datum.numberFields[yField] ?? 0,
                z: size(for: datum)
            )
        }
    }
    
    var metadata: NrdbMetadata { config.resultContainer.metadata }
    
    var selectedFacets: [String] { config.facets.selected }
    var selectedFields: [String] { config.selectedFields }
    
    var xField: String { config.plot.xField ?? ""}
    var yField: String { config.plot.yField ?? ""}
    var sizeField: String? { config.plot.sizeField }
    func size(for datum: NrdbResults.Datum) -> Double {
        guard let sizeField else { return 100 }
        return datum.numberFields[sizeField] ?? 100
    }
    
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
        Chart() {
            PointPlot(
                filteredData,
                x: .value( xField, \.x ),
                y: .value( yField, \.y )
            )
            .symbolSize(by: .value((sizeField ?? ""), \.z))
            .foregroundStyle(by: .value("Facet", \.facet))
            
        }
    }
}

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
