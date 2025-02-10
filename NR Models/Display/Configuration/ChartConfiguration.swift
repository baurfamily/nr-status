//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//

import AppIntents

enum ChartType : String, CaseIterable, AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Chart Type"
    
    static var caseDisplayRepresentations: [ChartType : DisplayRepresentation]  = [
        .bar: .init(stringLiteral: "Bar"),
        .line: .init(stringLiteral: "Line"),
        .plot: .init(stringLiteral: "Plot"),
        .pie: .init(stringLiteral: "Pie"),
        .table: .init(stringLiteral: "Table")
    ]
    
    case line, plot, pie, bar, table
    
    // want to refactor this to look at chart properties more deeply
    // for example, plot should only be used if there are at least two numeric fields
    static func cases(for resultContainer: NrdbResultContainer) -> [ChartType] {
        if resultContainer.isTimeseries {
            return [ .line, .table, .plot ]
        } else if resultContainer.isComparable {
            return [ .line, .table ]
        } else {
            return [ .plot, .bar, .pie, .table ]
        }
    }
    
    func isSupported(for resultContainer: NrdbResultContainer) -> Bool {
        return ChartType.cases(for: resultContainer).contains(self)
    }
}

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
    var pie: PieCharConfiguration = .init()
    var bar: BarChartConfiguration = .init()
    var plot: ScatterPlotConfig = .init()
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
        self.chartType = chartTypes.first
        if self.fields.count > 1 {
            self.plot.xField = self.fields[0].id
            self.plot.yField = self.fields[1].id
        }
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
    var logScale: Bool = false
    
    var xField: String?
    var yField: String?
    
    var sizeField: String?
}
