//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//


struct ChartConfiguration {
    var isStacked: Bool = false
    var isSmoothed: Bool = true
    var showDataPoints: Bool = false
    
    var fields: [SelectableField] = []
    var facets: [SelectableField] = []
    
    var selectedFields: [String] {
        fields.filter(\.isSelected).map(\.id)
    }
    var selectedFacets: [String] {
        facets.filter(\.isSelected).map(\.id)
    }
}
