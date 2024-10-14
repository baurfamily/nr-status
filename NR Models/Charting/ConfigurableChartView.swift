//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//

import SwiftUI
import Charts

struct ConfigurableChartView: View {
    let resultsContainer: NrdbResultContainer
    
    @State var config: ChartConfiguration
    
    var fields: [String] {
        if let first = resultsContainer.results.data.first {
            return first.numberFields.keys.map { "\($0)" }
        } else {
            return []
        }
    }
    var facets: [String] {
        resultsContainer.results.allFacets.sorted()
    }
    
    init(resultsContainer: NrdbResultContainer) {
        self.resultsContainer = resultsContainer
        
        // dynmaic fields not working yet?
        let data = resultsContainer.results.data
        let facets = resultsContainer.results.allFacets.sorted()
        
        let selectedFields = Set(data.first?.numberFields.keys.map(\.self) ?? [])
        let selectedFacets = Set(facets.count > 0 ? facets : [])
        
        self.config = .init(
            isStacked: false,
            isSmoothed: true,
            showDataPoints: false,
            selectedFields: selectedFields,
            selectedFacets: selectedFacets
        )
    }
    
    var body: some View {
        TimeseriesChartConfigView(
            fields: fields,
            facets: facets,
            config: $config
        )
        TimeseriesChart(resultsContainer: resultsContainer, config: config)
    }
}

#Preview("Timeseries (small)") {
    if let single = ChartSamples.sampleData(size: .small) {
        ConfigurableChartView(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}

#Preview("Faceted Timeseries (small)") {
    if let faceted = ChartSamples.sampleData(faceted: true, size: .small) {
        ConfigurableChartView(resultsContainer: faceted)
    } else {
        Text("No sample data")
    }
}

#Preview("Timeseries (medium)") {
    if let single = ChartSamples.sampleData() {
        ConfigurableChartView(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}

#Preview("Faceted Timeseries (medium)") {
    if let faceted = ChartSamples.sampleData(faceted: true) {
        ConfigurableChartView(resultsContainer: faceted)
    } else {
        Text("No sample data")
    }
}

#Preview("Timeseries comparable (small)") {
    if let single = ChartSamples.sampleData(comparable: true, size: .small) {
        ConfigurableChartView(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}
