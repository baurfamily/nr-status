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
            if summary.attribute.type == "numeric" {
                // testing, want this to be one of the tabs
                AttributeStatsChart(summary: summary, data: data)
            } else {
                AttributeChart(summary: summary, data: data, fieldName: fieldName)
            }
            
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
        Chart(data) { datum in
            LineMark(
                x: .value("Timestamp", datum.date),
                y: .value(fieldName, datum.numberFields[fieldName] ?? 0)
            )
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AttributeStatsChart : View {
    let summary: AttributeSummary
    var data: [NrdbResults.Datum]
    
    func fieldName(for metric: String) -> String {
        return "\(metric).\(summary.attribute.key)"
    }
    
    var body: some View {
        VStack {
            Chart(data) { datum in
                LineMark(
                    x: .value("Timestamp", datum.date),
                    y: .value("average", datum.numberFields[fieldName(for: "average")] ?? 0)
                )
                .lineStyle(by: .value("average", "average"))
                .interpolationMethod(.catmullRom)
                
                SigmaMark(datum: datum, key: summary.attribute.key)
                    .interpolationMethod(.catmullRom)
                RangeMark(datum: datum, key: summary.attribute.key)
                    .interpolationMethod(.catmullRom)
            }
            .chartForegroundStyleScale(range: Gradient(colors: [.yellow, .blue]))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SigmaMark : ChartContent {
    let datum: NrdbResults.Datum
    let key: String
    
    func fieldName(for metric: String) -> String {
        return "\(metric).\(key)"
    }
    
    var body: some ChartContent {
        AreaMark(
            x: .value("Timestamp", datum.date),
            yStart: .value("minus sigma", (datum.numberFields[fieldName(for: "average")] ?? 0)-(datum.numberFields[fieldName(for: "stddev")] ?? 0)),
            yEnd: .value("plus sigma", (datum.numberFields[fieldName(for: "average")] ?? 0)+(datum.numberFields[fieldName(for: "stddev")] ?? 0))
        )
        .foregroundStyle(by: .value("1-sigma", "1-sigma"))
        .interpolationMethod(.catmullRom)
        .opacity(0.5)
        
    }
}

struct RangeMark : ChartContent {
    let datum: NrdbResults.Datum
    let key: String
    
    func fieldName(for metric: String) -> String {
        return "\(metric).\(key)"
    }
    
    var body: some ChartContent {
        AreaMark(
            x: .value("Timestamp", datum.date),
            yStart: .value("minimum", datum.numberFields[fieldName(for: "min")] ?? 0),
            yEnd: .value("maximum", datum.numberFields[fieldName(for: "max")] ?? 0)
        )
        .foregroundStyle(by: .value("range", "range"))
        .opacity(0.2)
    }
}
