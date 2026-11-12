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
    
    // shown at the top of the inspector, above the chart configuration
    private var inspectorHeader = AnyView(EmptyView())
    
    @State private var ownConfigShowing: Bool = true
    private var externalConfigShowing: Binding<Bool>?
    @State var config: ChartConfiguration

    // lets a host show and hide the inspector; without one the view manages it
    private var configShowing: Binding<Bool> { externalConfigShowing ?? $ownConfigShowing }
    
    init(config: ChartConfiguration) {
        self.config = config
    }
   
    init(resultsContainer: NrdbResultContainer, format: ChartFormat? = nil, configurationShowing: Binding<Bool>? = nil) {
        let config = ChartConfiguration.init(
            resultContainer: resultsContainer
        )
        format?.apply(to: config)
        self.config = config
        self.externalConfigShowing = configurationShowing
    }
    
    func inspectorHeader<Header: View>(@ViewBuilder _ header: () -> Header) -> ConfigurableChartView {
        var copy = self
        copy.inspectorHeader = AnyView(header())
        return copy
    }
    
    private var chart: some View {
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
    }

    /// The chart alone, with no inspector; used when rendering to an image or PDF.
    func withoutConfiguration() -> ConfigurableChartView {
        var copy = self
        copy.hideConfiguration = true
        return copy
    }

    @ViewBuilder
    var body: some View {
        if hideConfiguration {
            chart
        } else {
            chart.inspector(isPresented: configShowing) { inspector }
        }
    }

    private var inspector: some View {
        VStack(alignment: .leading) {
                inspectorHeader
                
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
            .frame(maxHeight: .infinity, alignment: .top)
            .inspectorColumnWidth(min: 240, ideal: 300, max: 500)
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
