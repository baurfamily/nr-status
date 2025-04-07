//
//  QueryBuilder.swift
//  NR Status
//
//  Created by Eric Baur on 3/16/25.
//

struct QueryBuilder {
    var event: String
    var attributes: [Attribute] = []
    var facets: [Attribute] = []
    var predicates: [String] = []
    var timewindow: String = " SINCE 6 hours ago"
    var timeseries: Bool = false
    var timeseriesSize: String?
    
    var nrql: String {
        var query = "FROM \(event) SELECT "
        if !attributes.isEmpty {
            query += attributes.map(\.key).joined(separator: ", ")
        }
        
        query += timewindow
        
        if !facets.isEmpty {
            query += " FACET " + facets.map(\.key).joined(separator: ", ")
        }
        
        // need to figure out how to do aggrecates before this will work
        if timeseries {
            query += " TIMESERIES " + (timeseriesSize ?? "")
        }
        
        return query
    }
}
