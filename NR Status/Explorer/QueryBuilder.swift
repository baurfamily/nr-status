//
//  QueryBuilder.swift
//  NR Status
//
//  Created by Eric Baur on 3/16/25.
//

import SwiftUI

struct AggregateFunction : Equatable, Identifiable {
    var id: String { nrql }
    
    let name: String
    let alias: String? = nil
    
    // assume the attribute is the first paramter of the function
    // this isn't strictly true 100% of the time, but mostly...
    let attribute: Attribute
    
    // I really don't want to formalize these right now
    // I'm not even sure I'm going to implement it in the UI
    let extraParameters: String? = nil
    
    var nrql: String {
        "\(name)(\(attribute.key))"
    }
}

struct TimeIntervalChoice : Comparable, Identifiable {
    var id: TimeInterval { timeInterval }
    
    let timeInterval: TimeInterval
    let displayName: String
    
    static func < (lhs: TimeIntervalChoice, rhs: TimeIntervalChoice) -> Bool {
        return lhs.timeInterval < rhs.timeInterval
    }
    
    static var choices: [TimeIntervalChoice] = [
        .init(timeInterval: 60, displayName: "1 minute"),
        .init(timeInterval: 5*60, displayName: "5 minutes"),
        .init(timeInterval: 15*60, displayName: "15 minutes"),
        .init(timeInterval: 60*60, displayName: "1 hour"),
        .init(timeInterval: 6*60*60, displayName: "6 hours"),
        .init(timeInterval: 24*60*60, displayName: "1 day"),
        .init(timeInterval: 7*24*60*60, displayName: "1 week"),
    ]
}

struct TimeWindowChoice : Identifiable, Hashable {
    var id: String { since }
    
    let since: String
    
    var nrql: String { "SINCE \(since)" }
    
    static var choices: [TimeWindowChoice] = [
        .init(since: "1 hour ago"),
        .init(since: "6 hours ago"),
        .init(since: "1 day ago"),
        .init(since: "3 days ago"),
        .init(since: "1 week ago"),
        .init(since: "1 month ago"),
        .init(since: "3 month ago"),
    ]
}

struct QueryBuilder : Equatable {
    var event: String
    var defaultCount: Bool = true
    var attributes: [Attribute] = []
    var aggregates: [AggregateFunction] = []
    var facets: [Attribute] = []
    var predicates: [String] = []
    var timewindow: String = "SINCE 6 hours ago"
    var isTimeseries: Bool = false
    var timeseriesSize: String?
    var limit: Int = 0
    
    var isFaceted: Bool { !facets.isEmpty }
    var allowsAggregates: Bool { attributes.isEmpty || isFaceted }
    
    func contains(attribute: Attribute) -> Bool {
        return attributes.contains(where: { $0.key == attribute.key })
    }
    
    func contains(aggregate: String, with attribute: Attribute) -> Bool {
        return aggregates.contains(where: { $0.name == aggregate && $0.attribute.key == attribute.key })
    }
    
    func contains(facet attribute: Attribute) -> Bool {
        return facets.contains(where: { $0.key == attribute.key })
    }
    
    mutating func add(attribute: Attribute) {
        attributes.append(attribute)
    }
    
    mutating func add(aggregate: String, with attribute: Attribute) {
        aggregates.append(AggregateFunction(name: aggregate, attribute: attribute))
    }
    
    mutating func add(facet attribute: Attribute) {
        attributes.removeAll()
        // right now we only support single facets, which is sad, but true
        // this next line is only there to force a single facet at a time
        facets.removeAll()
        facets.append(attribute)
    }
    
    mutating func remove(attribute: Attribute) {
        attributes.removeAll { $0.key == attribute.key }
    }
    
    mutating func remove(aggregate: String, with attribute: Attribute) {
        aggregates.removeAll(where: { $0.name == aggregate && $0.attribute.key == attribute.key })
    }
    
    mutating func remove(facet attribute: Attribute) {
        facets.removeAll { $0.key == attribute.key }
    }
    
    var nrql: String {
        var query = "FROM \(event) SELECT "
        if attributes.isEmpty && aggregates.isEmpty {
            query += (defaultCount ? "COUNT(*)" : "*")
        } else {
            query += attributes.map(\.key).joined(separator: ", ")
            
            if !attributes.isEmpty && !aggregates.isEmpty {
                query += ", "
            }
            
            query += aggregates.map(\.nrql).joined(separator: ", ")
        }
        
        if !timewindow.isEmpty {
            query += " \(timewindow)"
        }
        

        
        if !facets.isEmpty {
            query += " FACET " + facets.map(\.key).joined(separator: ", ")
        }
        
        // need to figure out how to do aggrecates before this will work
        if isTimeseries {
            query += " TIMESERIES " + (timeseriesSize ?? "")
        } else if limit != 0{
            query += (limit == .max ? " LIMIT MAX" : " LIMIT \(limit)")
        }
        
        return query
    }
}
