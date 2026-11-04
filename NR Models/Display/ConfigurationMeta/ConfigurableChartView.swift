//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//

import SwiftUI
import Charts

struct ConfigurableChartView: View {
    var resultsContainer: NrdbResultContainer {
        config.resultContainer
    }
    var availableChartTypes: [ChartType] {
        config.chartTypes
    }

    var hideConfiguration: Bool = false
    
    @State var configShowing: Bool = true
    @State var config: ChartConfiguration
    
    init(config: ChartConfiguration) {
        self.config = config
    }
   
    init(resultsContainer: NrdbResultContainer) {
        let config = ChartConfiguration.init(
            resultContainer: resultsContainer
        )
        self.config = config
    }
    
    var body: some View {
        Section {
            switch config.chartType {
            case .line, nil: TimeseriesChart(config: config)
            case .billboard: BillboardChart(config: config)
            case .plot: ScatterPlot(config: config)
            case .pie: PieChart(config: config)
            case .bar: BarChart(config: config)
            case .table: TableChart(config: config)
            }
        }
        .inspectorColumnWidth(100)
        .inspector(isPresented: $configShowing) {
            ChartSelector(availableChartTypes: availableChartTypes, selectedChartType: $config.chartType)
            
            switch config.chartType {
            case .line, nil: TimeseriesChartConfigView(config: $config)
            case .billboard: BillboardChartConfigView(config: $config)
            case .plot: ScatterPlotConfigView(config: $config)
            case .pie: PieChartConfigView(config: $config)
            case .bar: BarChartConfigView(config: $config)
            case .table: Text("No additional configuration for tables")
            }
        }
    }
}

#Preview("Timeseries (medium)") {
    if let single = ChartSamples.sampleData(size: .tiny, statistics: true) {
        ConfigurableChartView(config: ChartConfiguration(resultContainer: single))
    } else {
        Text("No sample data")
    }
}

#Preview("Stats Tiny") {
    if let single = ChartSamples.sampleData(timeseries: false, size: .tiny, statistics: true) {
        ConfigurableChartView(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}

#Preview("Timeseries (small)") {
    if let single = ChartSamples.sampleData(size: .small) {
        ConfigurableChartView(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}

#Preview("Faceted (medium)") {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, size: .medium) {
        ConfigurableChartView(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}

#Preview("Faceted (multi/small)") {
    if let single = ChartSamples.sampleData(facet: .multi, timeseries: false, size: .small) {
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

#Preview("Faceted Timeseries (large/stats)") {
    if let faceted = ChartSamples.sampleData(facet: .single, timeseries: true, size: .large, statistics: true) {
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
