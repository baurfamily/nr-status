//
//  AttributeCharts.swift
//  NR Status
//
//  Created by Eric Baur on 3/18/25.
//

import SwiftUI
import Charts

struct AttributeCharts : View {
    let summary: AttributeSummary
    
    var results: NrdbResultContainer? { summary.timeseriesResultsContainer }
    var data: [NrdbResults.Datum] { summary.timeseriesResultsContainer?.results.data ?? [] }
    var fieldName: String { "average.\(summary.attribute.key)" }
    
    // maybe we should move this to the container object
    func dateFor(_ datum: NrdbResults.Datum) -> Date {
        if let results {
            if results.isComparable && datum.comparison == .previous{
                return results.adjustedTime(datum.beginTime!)
            } else if results.isEvents {
                return datum.timestamp!
            } else {
                return datum.beginTime!
            }
        }
        return .distantPast
    }
    
    var body: some View {
        Chart(data) { datum in
            LineMark(
                x: .value("Timestamp", dateFor(datum)),
                y: .value(fieldName, datum.numberFields[fieldName] ?? 0)
            )
            .foregroundStyle(by: .value("average", summary.attribute.key))
            .symbol(by: .value("average", summary.attribute.key))
        }
    }
}
