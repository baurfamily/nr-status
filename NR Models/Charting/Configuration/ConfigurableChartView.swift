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
    
    @State var fields: [SelectableField]
    @State var facets: [SelectableField]
    
    init(resultsContainer: NrdbResultContainer) {
        self.resultsContainer = resultsContainer
        
        var fields: [SelectableField] = []
        var facets: [SelectableField] = []
        
        if let first = resultsContainer.results.data.first {
            fields = SelectableField.wrap( first.numberFields.keys.sorted() )
        }
        facets = SelectableField.wrap( resultsContainer.results.allFacets.sorted() )
        
        self.fields = fields
        self.facets = facets
        
        self.config = .init(
            isStacked: false,
            isSmoothed: true,
            showDataPoints: false,
            fields: fields,
            facets: facets
        )
    }
    
    var body: some View {
        TimeseriesChartConfigView(config: $config)
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
    if let faceted = ChartSamples.sampleData(facet: .single, size: .small) {
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
    if let faceted = ChartSamples.sampleData(facet: .single) {
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
