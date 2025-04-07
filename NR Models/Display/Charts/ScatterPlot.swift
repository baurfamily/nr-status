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
        data.filter { selectedFacets.isEmpty || selectedFacets.contains($0.facet) }
    }
    
    init(config: ChartConfiguration) {
        self.config = config
        
        let allData = config.resultContainer.results.data
        
        self.data = allData.map { datum in
            NrdbResults.StatDatum(
                facet: datum.facet ?? "",
                color: colorValue(for: datum),
                x: datum.numberFields[xField] ?? 0,
                y: datum.numberFields[yField] ?? 0,
                z: size(for: datum),
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
    
    func colorValue(for datum: NrdbResults.Datum) -> String {
        if let field = config.plot.colorField {
            if let value = datum.stringFields[field] {
                return value
            } else if let value = datum.numberFields[field] {
                return "\(value)"
            }
        } else if config.plot.colorFacets {
            return datum.facet ?? ""
        }
        return ""
    }
    
    var body: some View {
        Chart() {
            PointPlot(
                filteredData,
                x: .value( xField, \.x ),
                y: .value( yField, \.y )
            )
            .symbolSize(by: .value((sizeField ?? ""), \.z))
            .foregroundStyle(by: .value("Facet", \.color))
        }
        .chartXScale(type: (config.plot.xLogScale ? .symmetricLog : .linear))
        .chartYScale(type: (config.plot.yLogScale ? .symmetricLog : .linear))
    }
}

#Preview("Event Data") {
    if let data = ChartSamples.sampleData(facet: .none, timeseries: false, comparable: false, size: .medium) {
        ConfigurableChartView(config: ChartConfiguration(resultContainer: data))
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .none, timeseries: false, comparable: false, size: .medium))
    }
}

#Preview("Timeseries (stats/tiny)") {
    if let single = ChartSamples.sampleData(size: .tiny, statistics: true) {
        ConfigurableChartView(config: ChartConfiguration(resultContainer: single))
    } else {
        Text("No sample data")
    }
}

#Preview("Timeseries (faceted/medium)") {
    if let single = ChartSamples.sampleData(facet: .single, size: .medium) {
        ScatterPlot(config: ChartConfiguration(resultContainer: single))
    } else {
        Text("No sample data")
    }
}

#Preview("Timeseries (faceted/large)") {
    if let single = ChartSamples.sampleData(facet: .single, size: .large) {
        ScatterPlot(config: ChartConfiguration(resultContainer: single))
    } else {
        Text("No sample data")
    }
}
