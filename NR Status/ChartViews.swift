//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI
import Charts

struct TimeseriesChart: View {
    var data: [NrdbResults.Datum]
    var metadata: NrdbMetadata
    
    @State var isStacked: Bool = false
    @State var isSmoothed: Bool = true
    @State var showDataPoints: Bool = false
    
    @State var selectedDate: Date?
    @State var selectedDateRange: ClosedRange<Date>?
    
    var body: some View {
        GroupBox {
            HStack {
                Toggle("Stacked", isOn: $isStacked).toggleStyle(.switch)
                Toggle("Smoothed", isOn: $isSmoothed).toggleStyle(.switch)
                Toggle("Points", isOn: $showDataPoints).toggleStyle(.switch)
            }
        }
        Chart(data) { datum in
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
            if isStacked {
                AreaMark(
                    x: .value("Timestamp", datum.beginTime!),
                    y: .value("Count", datum.numberFields["count"]!)
                )
                .foregroundStyle(by: .value("Facet", (datum.facet ?? "Count")))
                .interpolationMethod((isSmoothed ? .catmullRom : .linear))
                
            } else {
                LineMark(
                    x: .value("Timestamp", datum.beginTime!),
                    y: .value("Count", datum.numberFields["count"] ?? 0)
                )
                .lineStyle(lineStyle(for: datum.comparison))
                .foregroundStyle(by: .value("Facet", (datum.facet ?? "Count")))
                .symbol(by: .value("Facet", (datum.facet ?? "Count")))
                .symbolSize(showDataPoints ? 50 : 0)
                .interpolationMethod((isSmoothed ? .catmullRom : .linear))
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXSelection(range: $selectedDateRange)
    }
    
    func lineStyle(for comparison: NrdbResults.Datum.Comparison) -> StrokeStyle {
        if comparison == .previous {
            return .init()
        } else {
            return .init( dash: [ 10, 5, 2, 5 ] )
        }
    }
}

struct AnnotationView : View {
    var datum: NrdbResults.Datum
    var date: Date
    
    init(for datum: NrdbResults.Datum, on date: Date) {
        self.datum = datum
        self.date = date
    }
    
    var body: some View {
        Text(date.description)
    }
}

#Preview("Single Timeseries (small)") {
    if let single = ChartSamples.sampleData(size: .small) {
        TimeseriesChart(data: single.results.data, metadata: single.metadata)
    } else {
        Text("No sample data")
    }
}

#Preview("Faceted Timeseries (small)") {
    if let faceted = ChartSamples.sampleData(faceted: true, size: .small) {
        TimeseriesChart(data: faceted.results.data, metadata: faceted.metadata)
    } else {
        Text("No sample data")
    }
}
#Preview("Single Timeseries (medium)") {
    if let single = ChartSamples.sampleData() {
        TimeseriesChart(data: single.results.data, metadata: single.metadata)
    } else {
        Text("No sample data")
    }
}

#Preview("Faceted Timeseries (medium)") {
    if let faceted = ChartSamples.sampleData(faceted: true) {
        TimeseriesChart(data: faceted.results.data, metadata: faceted.metadata)
    } else {
        Text("No sample data")
    }
}
