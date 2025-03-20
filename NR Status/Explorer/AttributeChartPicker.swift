//
//  AttributeChartPicker.swift
//  NR Status
//
//  Created by Eric Baur on 3/18/25.
//

import SwiftUI
import Charts

struct AttributeChartPicker : View {
    let summary: AttributeSummary
    
    var results: NrdbResultContainer? { summary.timeseriesResultsContainer }
    var data: [NrdbResults.Datum] { summary.timeseriesResultsContainer?.results.data ?? [] }

    @State var fieldName: String
    
    init(summary: AttributeSummary) {
        self.summary = summary
        if summary.attribute.type == "numeric" {
            _fieldName = .init(initialValue: "average.\(summary.attribute.key)")
        } else {
            _fieldName = .init(initialValue: "uniqueCount.\(summary.attribute.key)")
        }
    }
    
    var body: some View {
        VStack {
            AttributeChart(summary: summary, data: data, fieldName: fieldName)
            
            Picker("", selection: $fieldName) {
                if summary.attribute.type == "numeric" {
                    Button("Average") {}.tag("average.\(summary.attribute.key)")
                }
                Button("Uniques") {}.tag("uniqueCount.\(summary.attribute.key)")
            }.pickerStyle(.palette)
            
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AttributeChart : View {
    let summary: AttributeSummary
    var data: [NrdbResults.Datum]
    let fieldName: String
    
    var body: some View {
        VStack {
            Chart(data) { datum in
                LineMark(
                    x: .value("Timestamp", datum.date),
                    y: .value(fieldName, datum.numberFields[fieldName] ?? 0)
                )
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
