//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//

import SwiftUI
import Charts
import WidgetKit
import AppKit

enum WidgetLegendPolicy {
    static func fits(labels: [String], width: CGFloat, additionalLines: Int = 0) -> Bool {
        guard !labels.isEmpty else { return additionalLines <= 2 }
        guard width > 14, additionalLines < 2 else { return false }
        let font = NSFont.preferredFont(forTextStyle: .caption1)
        let lineHeight = font.ascender - font.descender + font.leading
        let maximumHeight = CGFloat(2 - additionalLines) * lineHeight
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for label in labels {
            // Include the symbol and spacing when measuring each legend entry.
            let text = (label as NSString).boundingRect(
                with: CGSize(width: width - 14, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font]
            )
            let itemWidth = min(width, ceil(text.width) + 14)
            let itemHeight = max(lineHeight, ceil(text.height))
            if x > 0, x + 8 + itemWidth > width {
                y += rowHeight
                x = 0
                rowHeight = 0
            }
            if x > 0 { x += 8 }
            x += itemWidth
            rowHeight = max(rowHeight, itemHeight)
            if y + rowHeight > maximumHeight { return false }
        }
        return true
    }
}

struct ConfigurableChartView: View {
    var resultsContainer: NrdbResultContainer {
        config.resultContainer
    }
    var availableChartTypes: [ChartType] {
        config.chartTypes
    }

    var hideConfiguration: Bool = false
    private var usesDocumentSizing = false
    private var usesWidgetSizing = false
    private var widgetFamily: WidgetFamily = .systemLarge
    
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
    
    private var widgetLegendLabels: [String] {
        let labels: [String]
        switch config.chartType {
        case .line, nil:
            let chart = TimeseriesChart(config: config)
            labels = chart.data.filter { $0.facet == nil || chart.selectedFacets.contains($0.facet!) }
                .flatMap { datum in
                    chart.selectedFields.sorted().map { chart.seriesNames(for: $0, in: datum).1 }
                }
        case .bar:
            let chart = BarChart(config: config)
            labels = chart.filteredData.flatMap { datum -> [String] in
                if datum.isTimeseries {
                    return chart.selectedFields.map { chart.seriesNames(for: $0, in: datum).1 }
                }
                guard !chart.selectedFields.isEmpty else { return [] }
                if let facet = datum.facet, chart.selectedFacets.contains(facet) { return [facet] }
                if !chart.switchFieldsAndFacets, let facets = datum.facets, facets.count >= 2 { return [facets[0]] }
                return []
            }
        case .pie:
            labels = PieChart(config: config).data.compactMap(\.facet)
        case .plot:
            labels = ScatterPlot(config: config).filteredData.map(\.color)
        case .billboard, .table:
            labels = []
        }
        var seen = Set<String>()
        return labels.filter { seen.insert($0).inserted }
    }

    @ViewBuilder private var chart: some View {
        if usesWidgetSizing {
            GeometryReader { geometry in
                chartContent(legendVisibility:
                    widgetFamily == .systemSmall || !WidgetLegendPolicy.fits(
                        labels: widgetLegendLabels, width: geometry.size.width,
                        additionalLines: config.chartType == .plot && config.plot.sizeField != nil ? 1 : 0
                    ) ? .hidden : .automatic
                )
            }
        } else {
            chartContent()
        }
    }

    private func chartContent(legendVisibility: Visibility = .automatic) -> some View {
        Section {
            switch config.chartType {
            case .line, nil: TimeseriesChart(config: config)
            case .billboard: BillboardChart(config: config, fillsAvailableSpace: usesWidgetSizing)
            case .plot: ScatterPlot(config: config)
            case .pie: PieChart(config: config)
            case .bar:
                BarChart(
                    config: config, categoryAxisVisible: !usesWidgetSizing || widgetFamily == .systemLarge,
                    legendVisibility: legendVisibility
                )
            case .table: TableChart(config: config, isWidget: usesWidgetSizing)
            }
        }
        .chartXAxis(usesWidgetSizing && widgetFamily != .systemLarge ? .hidden : .automatic)
        .chartYAxis(usesWidgetSizing && widgetFamily != .systemLarge ? .hidden : .automatic)
        .chartLegend(legendVisibility)
    }

    /// The chart alone, with no inspector; used when rendering to an image or PDF.
    func withoutConfiguration() -> ConfigurableChartView {
        var copy = self
        copy.hideConfiguration = true
        return copy
    }

    func documentSized() -> ConfigurableChartView {
        var copy = self
        copy.usesDocumentSizing = true
        return copy
    }

    func widgetSized(for family: WidgetFamily = .systemLarge) -> ConfigurableChartView {
        var copy = self
        copy.hideConfiguration = true
        copy.usesWidgetSizing = true
        copy.widgetFamily = family
        return copy
    }

    @ViewBuilder
    var body: some View {
        if hideConfiguration {
            chart
                .frame(height: usesDocumentSizing ? config.documentHeight : nil)
        } else {
            chart
                .frame(height: usesDocumentSizing ? config.documentHeight : nil)
                .inspector(isPresented: configShowing) { inspector }
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
