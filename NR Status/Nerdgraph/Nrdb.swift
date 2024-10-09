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
        
        if metadata.facets.isEmpty {
            self.results = NrdbTimeseriesResults(data: try container.decode([NrdbTimeseriesResults.Datum].self, forKey: .results))
        } else {
            self.results = NrdbFacetResults(data: try container.decode([NrdbFacetResults.Datum].self, forKey: .results))
        }
    }
}

struct NrdbMetadata: Decodable {
    var timeWindow: TimeWindow
    var facets: [String] = []
}

struct TimeWindow: Decodable {
    var begin: Int
    var end: Int
    var since: String
    var until: String
}

protocol NrdbResults : Decodable {
    // just using this for abstraction of the results structs
}

struct NrdbTimeseriesResults: NrdbResults, Decodable {
    var data: [Datum]
    
    struct Datum : Decodable, Identifiable {
        enum CodingKeys: CodingKey {
            case beginTimeSeconds, count, endTimeSeconds
        }
        
        var id: Int { beginTimeSeconds }
        
        var beginTime: Date { Date(timeIntervalSince1970: Double(beginTimeSeconds)) }
        var endTime: Date { Date(timeIntervalSince1970: Double(endTimeSeconds)) }
        
        var beginTimeSeconds: Int
        var count: Int
        var endTimeSeconds: Int
    }
}

struct NrdbFacetResults: NrdbResults, Decodable {
    var data: [Datum]
    
    struct Datum : Decodable, Identifiable {
        enum CodingKeys: CodingKey {
            case beginTimeSeconds, count, endTimeSeconds, facet
        }
        
        var id: Int { beginTimeSeconds }
        
        var beginTime: Date { Date(timeIntervalSince1970: Double(beginTimeSeconds)) }
        var endTime: Date { Date(timeIntervalSince1970: Double(endTimeSeconds)) }
        
        var beginTimeSeconds: Int
        var count: Int
        var endTimeSeconds: Int
        var facet: String
    }
}
