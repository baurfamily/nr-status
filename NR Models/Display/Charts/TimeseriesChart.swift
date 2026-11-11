//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI
import Charts

struct TimeseriesChart: View {
    let config: ChartConfiguration
    
    var resultContainer: NrdbResultContainer {
        config.resultContainer
    }

    var data: [NrdbResults.Datum] { config.resultContainer.results.data }
    var metadata: NrdbMetadata { config.resultContainer.metadata }
    
    var selectedFacets: [String] { config.facets.selected }
    var selectedFields: [String] { config.selectedFields }

    @State var selectedDate: Date?
    @State var selectedDateRange: ClosedRange<Date>?
    
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
    
    func lineStyle(for comparison: NrdbResults.Datum.Comparison) -> StrokeStyle {
        if comparison == .current {
            return .init()
        } else {
            return .init( dash: [ 10, 5, 2, 5 ] )
        }
    }
    func dateFor(_ datum: NrdbResults.Datum) -> Date {
        if config.resultContainer.isComparable && datum.comparison == .previous{
            return config.resultContainer.adjustedTime(datum.beginTime!)
        } else if config.resultContainer.isEvents {
            return datum.timestamp!
        } else if let beginTime = datum.beginTime {
            return beginTime
        } else {
            return Date()
        }
    }
    
    var body: some View {
        // Read observable settings here so body tracks them; Chart's content closure may run outside body.
        let isStacked = config.timeseries.isStacked
        let interpolation: InterpolationMethod = config.timeseries.isSmoothed ? .catmullRom : .linear
        let showLines = config.timeseries.showLines
        let symbolSize: Double = config.timeseries.showDataPoints ? 50 : 0

        Chart(data.filter { $0.facet == nil || selectedFacets.contains($0.facet!)}) { datum in
            if let selectedDateRange {
                RectangleMark(
                    xStart: .value("Start", selectedDateRange.lowerBound, unit: .minute),
                    xEnd: .value("End", selectedDateRange.upperBound, unit: .minute)
                )
                .foregroundStyle(.gray.opacity(0.03 ))
                .zIndex(-2)
                .annotation(
                    position: .topLeading, spacing: 0,
                    overflowResolution: .init(
                        x: .fit(to: .chart),
                        y: .disabled
                    )
                ){ Text( "bar" ) }
            }
            if let selectedDate {
                RuleMark(
                    x: .value("Selected", selectedDate, unit: .minute)
                )
                .zIndex(-1)
                .annotation(
                    position: .topLeading, spacing: 0,
                    overflowResolution: .init(
                        x: .fit(to: .chart),
                        y: .disabled
                    )
                ){ AnnotationView(for: datum, on: selectedDate) }
            }
            
            ForEach(selectedFields.sorted(), id: \.self) { field in
                let seriesNames = seriesNames(for: field, in: datum)

                if isStacked {
                    AreaMark(
                        x: .value("Timestamp", dateFor(datum)),
                        y: .value(field, datum.numberFields[field] ?? 0)
                    )
                    .foregroundStyle(by: .value(seriesNames.0, seriesNames.1))
                    .interpolationMethod(interpolation)
                    
                } else if showLines {
                    LineMark(
                        x: .value("Timestamp", dateFor(datum)),
                        y: .value(field, datum.numberFields[field] ?? 0)
                    )
                    .lineStyle(lineStyle(for: datum.comparison))
                    .foregroundStyle(by: .value(seriesNames.0, seriesNames.1))
                    .symbol(by: .value(seriesNames.0, seriesNames.1))
                    .symbolSize(symbolSize)
                    .interpolationMethod(interpolation)
                } else {
                    PointMark(
                        x: .value("Timestamp", dateFor(datum)),
                        y: .value(field, datum.numberFields[field] ?? 0)
                    )
                    .foregroundStyle(by: .value(seriesNames.0, seriesNames.1))
                    .symbol(by: .value(seriesNames.0, seriesNames.1))
                    .symbolSize(symbolSize)
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXSelection(range: $selectedDateRange)
        // Chart doesn't redraw on style-only changes until the pointer moves; a new identity forces it.
        .id([isStacked, showLines, config.timeseries.isSmoothed, config.timeseries.showDataPoints])
    }
}

#Preview("Timeseries (medium)") {
    if let single = ChartSamples.sampleData(size: .tiny, statistics: true) {
        ConfigurableChartView(config: ChartConfiguration(resultContainer: single))
    } else {
        Text("No sample data")
    }
}

#Preview("Timeseries comparable (small)") {
    if let single = ChartSamples.sampleData(comparable: true, size: .small) {
        TimeseriesChart(config: ChartConfiguration(resultContainer: single))
    
    } else {
        Text("No sample data")
    }
}

#Preview("Timeseries (medium)") {
    if let single = ChartSamples.sampleData(size: .medium) {
        TimeseriesChart(config: ChartConfiguration(resultContainer: single))
    } else {
        Text("No sample data")
    }
}

#Preview("Timeseries (large)") {
    if let single = ChartSamples.sampleData(size: .large) {
        TimeseriesChart(config: ChartConfiguration(resultContainer: single))
    } else {
        Text("No sample data")
    }
}
