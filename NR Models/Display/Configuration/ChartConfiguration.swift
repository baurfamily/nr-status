//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//

import AppIntents
import SwiftUI

struct SelectableField: Identifiable, Hashable {
    let id: String
    var isSelected: Bool = true
    
    static func wrap(_ values: [String]) -> [Self] {
        return values.map { Self(id: $0) }
    }
}

struct ChartConfiguration {
    let resultContainer: NrdbResultContainer
    var chartType: ChartType?
    
    var facets: FacetsConfiguration
    
    var timeseries: TimeseriesConfiguration = .init()
    var billboard: BillboardConfiguration = .init()
    var pie: PieCharConfiguration = .init()
    var bar: BarChartConfiguration = .init()
    var plot: ScatterPlotConfig
    var fields: [SelectableField] = []
    
    var selectedFields: [String] {
        fields.filter(\.isSelected).map(\.id)
    }
    
    var chartTypes: [ChartType] {
        ChartType.cases(for: resultContainer)
    }
    
    init(resultContainer: NrdbResultContainer) {
        self.resultContainer = resultContainer
        
        self.fields = SelectableField.wrap( resultContainer.numberFieldNames.sorted() )
        self.facets = FacetsConfiguration(resultContainer: resultContainer)
        
        // must be last properties set
        self.plot = .init(fields: resultContainer.numberFieldNames)
        self.chartType = chartTypes.first
    }
}

struct FacetsConfiguration {
    var all: [SelectableField] = []
    var selected: [String] {
        all.filter(\.isSelected).map(\.id)
    }
    
    init(resultContainer: NrdbResultContainer) {
        self.all = SelectableField.wrap( resultContainer.allFacets.sorted() )
    }
}

struct TimeseriesConfiguration {
    var showDataPoints: Bool = false
    var showLines: Bool = true
    var isStacked: Bool = false
    var isSmoothed: Bool = true
}

struct PieCharConfiguration {
    var isDonut: Bool = true
    var isSeparated: Bool = true
    var otherThreshold: Int = 10
}

struct BarChartConfiguration {
    var pivotData: Bool = false
    var otherThreshold: Int = 10
}

struct ScatterPlotConfig {
    var colorFacets: Bool = true
    var xLogScale: Bool = false
    var yLogScale: Bool = false
    
    var xField: String?
    var yField: String?
    
    var sizeField: String?
    
    init(fields: [String]) {
        // this can't be used if there are less than 2 fields
        // it's probably somewhat unpredictable what order these end up in
        if fields.count >= 3 {
            xField = fields[0]
            yField = fields[1]
            sizeField = fields[2]
        } else if fields.count == 2 {
            xField = fields[0]
            yField = fields[1]
        }
    }
}

struct BillboardConfiguration {
    enum GaugeStyle : String, CaseIterable, AppEnum {
        static var typeDisplayRepresentation: TypeDisplayRepresentation = "Gauge Style"
        
        static var caseDisplayRepresentations: [GaugeStyle : DisplayRepresentation]  = [
            .linear: .init(stringLiteral: "Linear"),
            .compactLinear: .init(stringLiteral: "Compact Linear"),
            .linearCapacity: .init(stringLiteral: "Linear Capacity"),
            .circular: .init(stringLiteral: "Speedometer"),
            .circularCapacity: .init(stringLiteral: "Circular")
        ]
        
        case linear, compactLinear, linearCapacity, circular, circularCapacity
    }
    var showGauge: Bool = false
    var gaugeMax: Double = 100
    var gaugeStyle: BillboardConfiguration.GaugeStyle = .linear
}
