//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI
import Charts

struct TimeseriesChart: View {
    let resultsContainer: NrdbResultContainer
    
    var data: [NrdbResults.Datum] { resultsContainer.results.data }
    var metadata: NrdbMetadata { resultsContainer.metadata }
    
    @State var isStacked: Bool = false
    @State var isSmoothed: Bool = true
    @State var showDataPoints: Bool = false
    
    @State var selectedFields: Set<String> = []
    @State var selectedFacets: Set<String> = []
    
    @State var selectedDate: Date?
    @State var selectedDateRange: ClosedRange<Date>?
    
    var fields: [String] {
        if let first = data.first {
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
        
        if let fields = data.first?.numberFields.keys.map(\.self) {
            self._selectedFields = State(wrappedValue: Set(fields))
        }
        if facets.count > 0 {
            self._selectedFacets = State(wrappedValue: Set(facets))
        }
    }
    
    var body: some View {
        GroupBox {
            HStack {
                Toggle("Stacked", isOn: $isStacked).toggleStyle(.switch)
                Toggle("Smoothed", isOn: $isSmoothed).toggleStyle(.switch)
                Toggle("Points", isOn: $showDataPoints).toggleStyle(.switch)
                if fields.count > 1 {
                    SeriesSelectionView(fieldList: fields, selectedFields: $selectedFields)
                }
                if facets.count > 1 {
                    SeriesSelectionView(fieldList: facets, selectedFields: $selectedFacets)
                }
            }
        }
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
                        x: .value("Timestamp", datum.beginTime!),
                        y: .value(field, datum.numberFields[field]!)
                    )
                    .foregroundStyle(by: .value(seriesNames.0, seriesNames.1))
                    .interpolationMethod((isSmoothed ? .catmullRom : .linear))
                    
                } else {
                    LineMark(
                        x: .value("Timestamp", datum.beginTime!),
                        y: .value(field, datum.numberFields[field] ?? 0)
                    )
                    .lineStyle(lineStyle(for: datum.comparison))
                    .foregroundStyle(by: .value(seriesNames.0, seriesNames.1))
                    .symbol(by: .value(seriesNames.0, seriesNames.1))
                    .symbolSize(showDataPoints ? 50 : 0)
                    .interpolationMethod((isSmoothed ? .catmullRom : .linear))
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXSelection(range: $selectedDateRange)
    }
    
    func seriesNames(for field: String, in datum: NrdbResults.Datum ) -> (String,String) {
        let prefix = datum.isComparable ? "\(datum.comparison): " : ""
        let facetPrefix = datum.isFaceted ? "Facet" : "Data"
        
        let groupName = "\(prefix)\(facetPrefix)"
        let fieldName: String
        if let facet = datum.facet {
            fieldName = "\(facet)(\(field))"
        } else {
            fieldName = field
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

struct SeriesSelectionView : View {
    let fieldList: [String]
    
    @State private var show = false
    @Binding var selectedFields: Set<String>
    
    func toggle(field: String) {
        if selectedFields.contains(field) {
            selectedFields.remove(field)
        } else {
            self.selectedFields.insert(field)
        }
    }
    
    var body: some View {
        Menu {
            ForEach(fieldList, id: \.self) { field in
                Button(field, action: { toggle(field: field) })
            }
        } label: {
            Text(selectedFields.joined(separator: ", "))
        }
    }
    
}

//struct FieldSelectionView : View {
//    @State private var show = false
//    
//    var body: some View {
//        Button("Open Popover") {
//            self.show = true
//        }
//        .buttonStyle(.borderedProminent)
//        .popover(isPresented: self.$show,
//                 attachmentAnchor: .point(.center),
//                 arrowEdge: .top,
//                 content: {
//            Text("Hello, World!")
//                .padding()
//                .presentationCompactAdaptation(.none)
//        })
//    }
//    
//}

#Preview("Timeseries (small)") {
    if let single = ChartSamples.sampleData(size: .small) {
        TimeseriesChart(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}

#Preview("Faceted Timeseries (small)") {
    if let faceted = ChartSamples.sampleData(faceted: true, size: .small) {
        TimeseriesChart(resultsContainer: faceted)
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

#Preview("Faceted Timeseries (medium)") {
    if let faceted = ChartSamples.sampleData(faceted: true) {
        TimeseriesChart(resultsContainer: faceted)
    } else {
        Text("No sample data")
    }
}

#Preview("Timeseries comparable (small)") {
    if let single = ChartSamples.sampleData(comparable: true, size: .small) {
        TimeseriesChart(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}

#Preview("Faceted Timeseries comparable (small)") {
    if let faceted = ChartSamples.sampleData(faceted: true, comparable: true, size: .small) {
        TimeseriesChart(resultsContainer: faceted)
    } else {
        Text("No sample data")
    }
}
