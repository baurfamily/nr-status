//
//  Nrdb.swift
//  NR Status
//
//  Created by Eric Baur on 10/9/24.
//

import Foundation

// for convienence, most of the fields here are not optional
// this does mean that whatever query hydrates needs to supply
// all the fields - we're doing this to guarentee we can pick
// the appropriate results sub-type

// note: only implementing Decodable now, don't think I can about encoding
struct NrdbResultContainer : Decodable {
    enum CodingKeys : String, CodingKey {
        case nrql, results, metadata
    }
    var nrql: String
    var results: NrdbResults
    var metadata: NrdbMetadata
    
    // need to "manually" decode so we can use different types for the results
    // based on the type of query (faceted, timeseries, etc)
    init(from decoder : Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.nrql = try container.decode(String.self, forKey: .nrql)
        self.metadata = try container.decode(NrdbMetadata.self, forKey: .metadata)
        
        self.results = NrdbResults(data: try container.decode([NrdbResults.Datum].self, forKey: .results))
        
    }
}

struct NrdbMetadata: Decodable {
    var timeWindow: TimeWindow
    var facets: [String]?
}

struct TimeWindow: Decodable {
    var begin: Int
    var end: Int
    var since: String
    var until: String
}

struct NrdbResults: Decodable {
    var data: [Datum]
    
    var isTimeseries: Bool {
        return data.first?.isTimeseries ?? false
    }
    
    struct Datum : Decodable, Identifiable {
        var id: Double { beginTimeSeconds ?? 0 }
        
        var isTimeseries: Bool {
            if beginTimeSeconds != nil && endTimeSeconds != nil {
                return true
            } else {
                return false
            }
        }
        
        var beginTime: Date? {
            guard let beginTimeSeconds else { return nil }
            return Date(timeIntervalSince1970: beginTimeSeconds)
        }
        var endTime: Date? {
            guard let endTimeSeconds else { return nil }
            return Date(timeIntervalSince1970: endTimeSeconds)
        }
        
        var beginTimeSeconds: Double?
        var count: Int
        var endTimeSeconds: Double?
        var facet: String?
    }
}
