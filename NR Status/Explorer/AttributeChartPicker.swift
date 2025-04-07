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
    
    @State var showRange: Bool = false

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
                switch fieldName {
                case "average.\(summary.attribute.key)":
                    AttributeStatsChart(summary: summary, data: data, showRange: showRange)
                    
                case "percentile.\(summary.attribute.key)":
                    CandleStickChart(data: data, key: summary.attribute.key, showRange: showRange)
                    
                case "uniqueCount.\(summary.attribute.key)":
                    AttributeChart(summary: summary, data: data, fieldName: fieldName)
                    
                default:
                    Text("I have no idea what to show now... (for \(fieldName)")
                }
                Toggle("Show Range", isOn: $showRange)
            } else {
                AttributeChart(summary: summary, data: data, fieldName: fieldName)
            }
            
            Picker("", selection: $fieldName) {
                if summary.attribute.type == "numeric" {
                    Button("Average") {}.tag("average.\(summary.attribute.key)")
                    Button("Range") {}.tag("percentile.\(summary.attribute.key)")
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
    var showRange: Bool
    
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
                .lineStyle(by: .value("average", "Average"))
                .interpolationMethod(.catmullRom)
                
                SigmaMark(datum: datum, key: summary.attribute.key)
                    .interpolationMethod(.catmullRom)
                if showRange {
                    RangeMark(datum: datum, key: summary.attribute.key)
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartForegroundStyleScale(range: Gradient(colors: [.yellow, .blue]))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CandleStickChart : View {
    let data: [NrdbResults.Datum]
    let key: String
    let showRange: Bool
    
    var body: some View {
        Chart(data) { datum in
            if let percentiles = datum.numericDictFields["percentile.\(key)"] {
                CandleStickMark(
                    timestamp: datum.date,
                    min: percentiles["5"]!,
                    firstQ: percentiles["25"]!,
                    median: percentiles["50"]!,
                    thirdQ: percentiles["75"]!,
                    max: percentiles["95"]!,
                    showRange: showRange
                )
                LineMark(
                    x: .value("Timestamp", datum.date),
                    y: .value("Median", datum.numericDictFields["percentile.\(key)"]!["50"]!)
                )
                .foregroundStyle(by:.value("median", "Median"))
            }
        }
    }
}

struct CandleStickMark: ChartContent {
    let timestamp: Date
    let min: Double
    let firstQ: Double
    let median: Double
    let thirdQ: Double
    let max: Double
    
    let showRange: Bool
    
    var body: some ChartContent {
        Plot {
            // 1st Q - 3nd Q
            BarMark(
                x: .value("Timestamp", timestamp),
                yStart: .value("1st Q", firstQ),
                yEnd: .value("3rd Q", thirdQ),
                width: 10
            )
            .cornerRadius(4)
            RuleMark(
                x: .value("Timestamp", timestamp),
                yStart: .value("Median", median + 0.01*median),
                yEnd: .value("Median", median -  0.01*median)
            ).foregroundStyle(by:.value("Inner Quartile Range", "IQR"))
            
            if showRange {
                BarMark(
                    x: .value("Timestamp", timestamp),
                    yStart: .value("Max", max),
                    yEnd: .value("Min,", min),
                    width: 3
                )
                .foregroundStyle(by:.value("5th/95th Percentile", "P5/P95"))
                .cornerRadius(1)
                .opacity(0.5)
            }
        }
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
        .foregroundStyle(by: .value("1-sigma", "±1σ"))
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
        .foregroundStyle(by: .value("range", "Range"))
        .opacity(0.2)
    }
}
