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
        .pie: .init(stringLiteral: "Pie"),
        .table: .init(stringLiteral: "Table")
    ]
    
    case line, pie, bar, table
    
    static func cases(for resultContainer: NrdbResultContainer) -> [ChartType] {
        if resultContainer.isTimeseries {
            return [ .line, .table ]
        } else if resultContainer.isComparable {
            return [ .line, .table ]
        } else {
            return [ .bar, .pie, .table ]
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
    
    var timeseries: TimeseriesConfiguration
    var facets: FacetsConfiguration
    var pie: PieCharConfiguration
    var bar: BarChartConfiguration
    var fields: [SelectableField] = []
    
    var selectedFields: [String] {
        fields.filter(\.isSelected).map(\.id)
    }
    
    var chartTypes: [ChartType] {
        ChartType.cases(for: resultContainer)
    }
    
    init(resultContainer: NrdbResultContainer) {
        self.resultContainer = resultContainer
        
        
        if let first = resultContainer.results.data.first {
            self.fields = SelectableField.wrap( first.numberFields.keys.sorted() )
        }
        self.timeseries = TimeseriesConfiguration()
        self.facets = FacetsConfiguration(resultContainer: resultContainer)
        self.pie = PieCharConfiguration()
        self.bar = BarChartConfiguration()
        
        // must be last property set
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
