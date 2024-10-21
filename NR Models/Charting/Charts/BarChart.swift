//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI
import Charts

struct BarChart: View {
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
                BarMark(
                    y: .value(datum.facet!, datum.numberFields["count"]!)
                )
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

#Preview("Timeseries comparable (small)") {
    if let single = ChartSamples.sampleData(comparable: false, size: .small) {
        BarChart(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}

//#Preview("Timeseries (medium)") {
//    if let single = ChartSamples.sampleData() {
//        TimeseriesChart(resultsContainer: single)
//    } else {
//        Text("No sample data")
//    }
//}
