//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//

enum ChartType : String, CaseIterable {
    case line, pie, bar, table
}

struct ChartConfiguration {
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
    
    func chartTypeFor(results: NrdbResultContainer) -> [ChartType] {
        if results.isTimeseries {
            return [ .line, .table ]
        } else if results.isComparable {
            return [ .line, .table ]
        } else {
            return [ .bar, .pie, .table ]
        }
    }
}
