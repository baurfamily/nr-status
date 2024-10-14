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
    
    var selectedFields: Set<String> = Set<String>()
    var selectedFacets: Set<String> = Set<String>()
}
