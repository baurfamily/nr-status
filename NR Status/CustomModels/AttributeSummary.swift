//
//  AttributeSummary.swift
//  NR Status
//
//  Created by Eric Baur on 3/18/25.
//

import Foundation

struct AttributeSummary : Identifiable{
    // *technically* this wouldn't be unique, except we are going to
    // use a cache to force it to be
    var id: String { "\(attribute.event):\(attribute.key)" }
    
    let attribute: Attribute
    
    var cardinality: Int = 0
    var average: Double?
    var minimum: Double?
    var maximum: Double?
    
    var samples: [String] = []
    
    var timeseriesResultsContainer: NrdbResultContainer?
    
    // because of the way the UI is built, this could get called multiple times
    // for the same attribute in a short span; and since the call is over 1 DAY
    // it seems silly to requery every time
    // TODO: add some level of TTL here
    static var cache: [String: AttributeSummary] = [:]
    
    static func generate(from attribute: Attribute) async -> Self {
        guard cache[attribute.id] == nil else {
            return cache[attribute.id]!
        }
        
        var summary = AttributeSummary(attribute: attribute)
        
        let results = await Queries().getNrqlData(query: """
            SELECT
                uniqueCount(`\(attribute.key)`),
                uniques(`\(attribute.key)`),
                average(`\(attribute.key)`),
                min(`\(attribute.key)`),
                max(`\(attribute.key)`)
            FROM \(attribute.event)
            SINCE 1 day ago
        """)
        
        if let results {
            if let first = results.data.first {
                summary.cardinality = Int(first.numberFields["uniqueCount.\(attribute.key)"] ?? 0)
                
                summary.average = first.numberFields["average.\(attribute.key)"]
                summary.minimum = first.numberFields["min.\(attribute.key)"]
                summary.maximum = first.numberFields["max.\(attribute.key)"]
                
                let stringSamples = first.stringArrayFields["uniques.\(attribute.key)"] ?? []
                let numericSamples = first.numericArrayFields["uniques.\(attribute.key)"] ?? []
                
                if !stringSamples.isEmpty {
                    summary.samples = stringSamples
                } else if !numericSamples.isEmpty {
                    summary.samples = numericSamples.map { x in
                        return (floor(x) == x ? "\(Int(x))" : String(format: "%.3f", x))
                    }
                }
                
                // okay, this is a bit of a hack... basically, we only see a small number
                // of samples when the values are fractional. No idea why uniques() doesn't work here
                if attribute.type == "numeric" && summary.samples.count == 1 && summary.samples[0] == "0" {
                    let uniquesResult = await Queries().getNrqlData(query: """
                        SELECT `\(attribute.key)`
                        FROM \(attribute.event)
                        WHERE `\(attribute.key)` IS NOT NULL
                        SINCE 1 day ago
                        LIMIT 100
                    """)
                    
                    if let uniquesResult {
                        let samples = uniquesResult.data.map { String($0.numberFields[attribute.key] ?? .nan) }
                        let sampleSet = Set(samples)
                        summary.samples = sampleSet.sorted()
                    }
                }
            }
        }
        
        if attribute.type == "numeric" {
            summary.timeseriesResultsContainer = await Queries().getNrqlData(query: """
                SELECT
                    count(*),
                    uniqueCount(`\(attribute.key)`),
                    average(`\(attribute.key)`),        
                    percentile(`\(attribute.key)`, 0, 5, 25, 50, 75, 95, 100),
                    min(`\(attribute.key)`),
                    max(`\(attribute.key)`),
                    stddev(`\(attribute.key)`)
                FROM \(attribute.event)
                SINCE 1 day ago
                TIMESERIES 1 hour
            """)
        } else if attribute.type == "string" {
            summary.timeseriesResultsContainer = await Queries().getNrqlData(query: """
                SELECT
                    count(*),
                    uniqueCount(`\(attribute.key)`)
                FROM \(attribute.event)
                SINCE 1 day ago
                TIMESERIES 1 hour
            """)
        }
        cache[attribute.id] = summary
        return summary
    }
}
