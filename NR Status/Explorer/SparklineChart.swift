//
//  SparklineChart.swift
//  NR Status
//
//  Created by Eric Baur on 4/4/25.
//

import SwiftUI
import Charts

// has to be timeseries data, has to have 'key' at all points
struct SparklineChart : View {
    let data: [NrdbResults.Datum]
    let key: String?
    let keyTuple: (String, String)?
    
    init(data: [NrdbResults.Datum], key: String) {
        self.data = data
        self.key = key
        self.keyTuple = nil
    }
    
    init(data: [NrdbResults.Datum], keyTuple: (String, String)) {
        self.data = data
        self.key = nil
        self.keyTuple = keyTuple
    }

    func valueFor(datum: NrdbResults.Datum) -> PlottableValue<Double> {
        if let key = key {
            if let val = datum.numberFields[key] {
                return .value(key, val)
            }
        }
        
        if let keyTuple = keyTuple {
            if let dict = datum.numericDictFields[keyTuple.0] {
                if let val = dict[keyTuple.1] {
                    return .value("\(keyTuple.0)-\(keyTuple.1)", val)
                }
            }
        }
        
        return PlottableValue.value("unknown", 0)
    }
    
    var body : some View {
        Chart(data) { datum in
            LineMark(
                x: .value("Timestamp", datum.beginTime!),
                y: valueFor(datum: datum)
            )
        }
        .frame(width: 100, height: 20)
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}
