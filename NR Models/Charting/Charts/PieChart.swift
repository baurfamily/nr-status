//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI
import Charts

struct PieChart: View {
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
        if resultsContainer.results.isComparable && datum.comparison == .previous{
             return resultsContainer.results.adjustedTime(datum.beginTime!)
        } else {
            return datum.beginTime!
        }
    }
    
    var body: some View {
        Chart(data.filter { $0.facet == nil || selectedFacets.contains($0.facet!)}) { datum in
//            ForEach(selectedFacets.sorted(), id: \.self) { field in
//                let seriesNames = seriesNames(for: field, in: datum)
                SectorMark(
                    angle: .value(datum.facet!, datum.numberFields["count"]!),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                )
                .cornerRadius(2)
                .foregroundStyle(
                    by: .value(
                        Text(verbatim: datum.facet!),
                        datum.facet!
                    )
                )
//            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXSelection(range: $selectedDateRange)
    }
}

#Preview("Single facet (small)") {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, comparable: false, size: .small) {
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
