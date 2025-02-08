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
    let hideConfiguration: Bool
    
    @State var configShowing: Bool = true
    @State var config: ChartConfiguration
    
    init(resultsContainer: NrdbResultContainer, hideConfiguration: Bool = false) {
        self.resultsContainer = resultsContainer
        self.hideConfiguration = hideConfiguration
        
        self.config = .init(
            resultContainer: resultsContainer
        )
    }
    
    var body: some View {
        TimeseriesChart(config: config)
            .inspectorColumnWidth(100)
            .inspector(isPresented: $configShowing) {
                TimeseriesChartConfigView(config: $config)
            }
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
