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
    
    var isStacked: Bool = false
    var isSmoothed: Bool = true
    var showDataPoints: Bool = false
    var chartType: ChartType?
    
    var fields: [SelectableField] = []
    var facets: [SelectableField] = []
    
    var selectedFields: [String] {
        fields.filter(\.isSelected).map(\.id)
    }
    var selectedFacets: [String] {
        facets.filter(\.isSelected).map(\.id)
    }
    
    var chartTypes: [ChartType] {
        ChartType.cases(for: resultContainer)
    }
    
    init(resultContainer: NrdbResultContainer) {
        self.resultContainer = resultContainer
        
        if let first = resultContainer.results.data.first {
            self.fields = SelectableField.wrap( first.numberFields.keys.sorted() )
        }
        self.facets = SelectableField.wrap( resultContainer.allFacets.sorted() )
        self.chartType = chartTypes.first
    }
}

struct BasicConfiguration {
    let resultContainer: NrdbResultContainer
    
    var fields: [SelectableField] = []
    var selectedFields: [String] {
        fields.filter(\.isSelected).map(\.id)
    }
    
    init?(resultContainer: NrdbResultContainer) {
        self.resultContainer = resultContainer
        
        if let first = resultContainer.results.data.first {
            self.fields = SelectableField.wrap( first.numberFields.keys.sorted() )
        }
    }
}

struct FacetedConfiguration {
    var facets: [SelectableField] = []
    var selectedFacets: [String] {
        facets.filter(\.isSelected).map(\.id)
    }
    
    init(resultContainer: NrdbResultContainer) {
        self.facets = SelectableField.wrap( resultContainer.allFacets.sorted() )
    }
}

struct TimeseriesConfiguration {
    var showDataPoints: Bool = false
}

struct AreaChartConfiguration {
    var basicConfiguration: BasicConfiguration
    var facetedConfiguration: FacetedConfiguration?
    var timeseriesConfiguration: TimeseriesConfiguration?
}

struct BarChartConfiguration {
    var basicConfiguration: BasicConfiguration
    var facetedConfiguration: FacetedConfiguration
}

struct BillBoardConfiguration {
    var basicConfiguration: BasicConfiguration
    var facetConfiguration: FacetedConfiguration?
}
    
struct LineChartConfiguration {
    var basicConfiguratin: BasicConfiguration
    var timeseriesConfiguration: TimeseriesConfiguration
}

struct PieChartConfiguration {
    var basicConfiguration: BasicConfiguration
    var facetedConfiguration: FacetedConfiguration
}

struct TableConfiguration {
    var basicConfiguration: BasicConfiguration
}

//TODO: Stacked Bar, Bullet, Heatmap, Histogram
