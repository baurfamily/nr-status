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
    var isFaceted: Bool {
        return data.first?.facet != nil
    }
    
    struct Datum : Decodable, Identifiable {
        enum CodingKeys : String, CodingKey {
            case beginTimeSeconds, endTimeSeconds, count, facet
        }
        
        var id: Double { beginTime?.timeIntervalSince1970 ?? 0 }
        
        var isTimeseries: Bool {
            if beginTime != nil && endTime != nil {
                return true
            } else {
                return false
            }
        }
        
        var beginTime: Date?
        var endTime: Date?
        
        var count: Int?
        var facet: String?
        var facets: [String]?
        
        var numberFields: [String: Double] = [:]
        var stringFields: [String: String] = [:]
        
        var fieldNames: [String] = []
        
        init(from decoder : Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.beginTime = try container.decodeIfPresent(Date.self, forKey: .beginTimeSeconds)
            self.endTime = try container.decodeIfPresent(Date.self, forKey: .endTimeSeconds)
            
            if let facet = try container.decodeIfPresent(String.self, forKey: .facet) {
                self.facet = facet
            } else if let facets = try container.decodeIfPresent([String].self, forKey: .facet) {
                self.facets = facets
            }
            
            // take the remainder and stuff it into a dictionaries
            for key in container.allKeys {
                if ["beginTimeSeconds", "endTimeSecond", "facet"].contains(key.rawValue) {
                    continue
                }
                
                if let doubleValue = try? container.decode(Double.self, forKey: key) {
                    self.numberFields[key.rawValue] = doubleValue
                } else if let stringValue = try? container.decode(String.self, forKey: key) {
                    self.stringFields[key.rawValue] = stringValue
                } else {
                    print("unable to decode key: \(key)")
                    return
                }
                
                fieldNames.append(key.rawValue)
            }
        }
    }
}
