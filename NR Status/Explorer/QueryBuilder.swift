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
    
    // assume the attribute is the first paramter of the function
    // this isn't strictly true 100% of the time, but mostly...
    let attribute: Attribute
    
    var nrql: String {
        "\(name)(\(attribute.key))"
    }
}

struct TimeIntervalChoice : Comparable, Identifiable, Hashable {
    var id: TimeInterval { timeInterval }
    
    let timeInterval: TimeInterval
    let displayName: String
    
    static func < (lhs: TimeIntervalChoice, rhs: TimeIntervalChoice) -> Bool {
        return lhs.timeInterval < rhs.timeInterval
    }
    
    static let choices: [TimeIntervalChoice] = [
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
    
    static let choices: [TimeWindowChoice] = [
        .init(since: "1 hour ago"),
        .init(since: "6 hours ago"),
        .init(since: "1 day ago"),
        .init(since: "3 days ago"),
        .init(since: "1 week ago"),
        .init(since: "1 month ago"),
        .init(since: "3 month ago"),
    ]
    
    static let `default` = TimeWindowChoice(since: "6 hours ago")
}

enum TimeseriesSize : Hashable {
    case auto
    case interval(TimeIntervalChoice)
    case max
    
    var nrql: String {
        switch self {
        case .auto: "AUTO"
        case .interval(let choice): choice.displayName
        case .max: "MAX"
        }
    }
}

enum ResultLimit : Hashable {
    case auto
    case count(Int)
    case max
    
    static let choices: [ResultLimit] = [.auto, .count(10), .count(100), .count(1000), .max]
    
    var displayName: String {
        switch self {
        case .auto: "AUTO"
        case .count(let value): "\(value)"
        case .max: "MAX"
        }
    }
    
    // nil means leave the LIMIT clause out
    var nrql: String? {
        switch self {
        case .auto: nil
        case .count(let value): "LIMIT \(value)"
        case .max: "LIMIT MAX"
        }
    }
}

private extension Array where Element == Attribute {
    func contains(key: String) -> Bool {
        contains { $0.key == key }
    }
    
    mutating func removeAll(key: String) {
        removeAll { $0.key == key }
    }
}

struct QueryBuilder : Equatable {
    var event: String
    var defaultCount: Bool = true
    var attributes: [Attribute] = []
    var aggregates: [AggregateFunction] = []
    var facets: [Attribute] = []
    var predicates: [String] = []
    var timewindow: TimeWindowChoice = .default
    var isTimeseries: Bool = false
    var timeseriesSize: TimeseriesSize = .auto
    var limit: ResultLimit = .auto
    
    var isFaceted: Bool { !facets.isEmpty }
    var allowsAggregates: Bool { attributes.isEmpty || isFaceted }
    
    func contains(attribute: Attribute) -> Bool {
        attributes.contains(key: attribute.key)
    }
    
    func contains(aggregate: String, with attribute: Attribute) -> Bool {
        aggregates.contains(where: { $0.name == aggregate && $0.attribute.key == attribute.key })
    }
    
    func contains(facet attribute: Attribute) -> Bool {
        facets.contains(key: attribute.key)
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
        attributes.removeAll(key: attribute.key)
    }
    
    mutating func remove(aggregate: String, with attribute: Attribute) {
        aggregates.removeAll(where: { $0.name == aggregate && $0.attribute.key == attribute.key })
    }
    
    mutating func remove(facet attribute: Attribute) {
        facets.removeAll(key: attribute.key)
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
        
        query += " \(timewindow.nrql)"
        
        if !facets.isEmpty {
            query += " FACET " + facets.map(\.key).joined(separator: ", ")
        }
        
        // need to figure out how to do aggrecates before this will work
        if isTimeseries {
            query += " TIMESERIES \(timeseriesSize.nrql)"
        } else if let limitClause = limit.nrql {
            query += " \(limitClause)"
        }
        
        return query
    }
}
