//
//  ChartSelectionView.swift
//  NR Status
//
//  Created by Eric Baur on 10/23/24.
//

import SwiftUI
import Charts

struct ChartSelectionView: View {
    let resultsContainer: NrdbResultContainer
    
    @State var config: ChartConfiguration
    
    init(resultsContainer: NrdbResultContainer) {
        self.resultsContainer = resultsContainer
        
        var fields: [SelectableField] = []
        var facets: [SelectableField] = []
        
        if let first = resultsContainer.results.data.first {
            fields = SelectableField.wrap( first.numberFields.keys.sorted() )
        }
        facets = SelectableField.wrap( resultsContainer.allFacets.sorted() )
        
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

#Preview("Single facet (small)") {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, comparable: false, size: .small) {
        Text("data \(single.results.data.count)")
        PieChart(resultsContainer: single)
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .single, timeseries: false, comparable: false, size: .small))
    }
}

#Preview("Double facet (small)") {
    if let double = ChartSamples.sampleData(facet: .multi, timeseries: false, comparable: false, size: .small) {
        PieChart(resultsContainer: double)
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .multi, timeseries: false, comparable: false, size: .small))
    }
}
