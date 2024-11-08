//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//

enum ChartType : String, CaseIterable {
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
    }
}
