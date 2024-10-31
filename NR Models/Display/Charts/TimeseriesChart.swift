//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI
import Charts

struct TimeseriesChart: View {
    var resultsContainer: NrdbResultContainer
    var config: ChartConfiguration = ChartConfiguration()

    var data: [NrdbResults.Datum] { resultsContainer.results.data }
    var metadata: NrdbMetadata { resultsContainer.metadata }
    
    var selectedFacets: [String] { config.selectedFacets }
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
        if resultsContainer.isComparable && datum.comparison == .previous{
             return resultsContainer.adjustedTime(datum.beginTime!)
        } else {
            return datum.beginTime!
        }
    }
    
    var body: some View {
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

                if config.isStacked {
                    AreaMark(
                        x: .value("Timestamp", dateFor(datum)),
                        y: .value(field, datum.numberFields[field]!)
                    )
                    .foregroundStyle(by: .value(seriesNames.0, seriesNames.1))
                    .interpolationMethod((config.isSmoothed ? .catmullRom : .linear))
                    
                } else {
                    LineMark(
                        x: .value("Timestamp", dateFor(datum)),
                        y: .value(field, datum.numberFields[field] ?? 0)
                    )
                    .lineStyle(lineStyle(for: datum.comparison))
                    .foregroundStyle(by: .value(seriesNames.0, seriesNames.1))
                    .symbol(by: .value(seriesNames.0, seriesNames.1))
                    .symbolSize(config.showDataPoints ? 50 : 0)
                    .interpolationMethod((config.isSmoothed ? .catmullRom : .linear))
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXSelection(range: $selectedDateRange)
    }
}

#Preview("Timeseries comparable (small)") {
    if let single = ChartSamples.sampleData(comparable: true, size: .small) {
        TimeseriesChart(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}

#Preview("Timeseries (medium)") {
    if let single = ChartSamples.sampleData() {
        TimeseriesChart(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}
