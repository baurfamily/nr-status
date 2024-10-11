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
    var isComparable: Bool {
        return data.first?.isComparable != nil
    }
    
    struct Datum : Decodable, Identifiable {
        enum CodingKeys : String, CodingKey, CaseIterable {
            case beginTimeSeconds, endTimeSeconds, facet, comparison
        }
        // this responds to any key passed and claims it
        // which allows us to decode "unknwon" keys
        struct UnknownCodingKey: CodingKey {
            init?(stringValue: String) { self.stringValue = stringValue }
            let stringValue: String

            init?(intValue: Int) { return nil }
            var intValue: Int? { return nil }
        }
        enum Comparison : String, Decodable {
            case current, previous
        }
        
        var id: Double { beginTime?.timeIntervalSince1970 ?? 0 }
        
        var isTimeseries: Bool {
            if beginTime != nil && endTime != nil {
                return true
            } else {
                return false
            }
        }
        
        // these will only show up if the data is a TIMESERIES
        var beginTime: Date?
        var endTime: Date?
        
        // if COMPARE WITH was used in the query, this will be populated
        var comparison: Comparison = .current
        
        // only true if the "comparrison" field is present
        var isComparable: Bool = false
        
        // these will be left nil if there are no facets in the data
        var facet: String?
        var facets: [String]?
        
        // this is the dynamic fields, all the stuff specified in the query
        // examples:
        // count(*) => "count"
        // uniqueCount(name) => "uniqueCount.name"
        // someField => "someField"
        var numberFields: [String: Double] = [:]
        var stringFields: [String: String] = [:]
        
        // in theory this could be dynamic, but currently it's filled by the decoder
        var fieldNames: [String] = []
        
        init(from decoder : Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if let beginTimeSeconds = try container.decodeIfPresent(Double.self, forKey: .beginTimeSeconds) {
                self.beginTime = Date(timeIntervalSince1970: beginTimeSeconds)
            }
            if let endTimeSeconds = try container.decodeIfPresent(Double.self, forKey: .endTimeSeconds) {
                self.endTime = Date(timeIntervalSince1970: endTimeSeconds)
            }
//            self.beginTime = try container.decodeIfPresent(Date.self, forKey: .beginTimeSeconds)
//            self.endTime = try container.decodeIfPresent(Date.self, forKey: .endTimeSeconds)
            
            // if the comparison key is not present, we leave the default
            if container.allKeys.contains(.comparison) {
                self.isComparable = true
                self.comparison = try container.decode(Comparison.self, forKey: .comparison)
            }
            
            // for now, we store a single facet differently than a multi-facet
            if let facet = try container.decodeIfPresent(String.self, forKey: .facet) {
                self.facet = facet
            } else if let facets = try container.decodeIfPresent([String].self, forKey: .facet) {
                self.facets = facets
            }
            
            let otherContainer = try decoder.container(keyedBy: UnknownCodingKey.self)
            let knownKeys = CodingKeys.allCases.map { $0.stringValue }
            
            // take the remainder and stuff it into a dictionaries
            for key in otherContainer.allKeys {
                print("key: \(key.stringValue)")
                print("checking: \(knownKeys)")
                guard (!knownKeys.contains(key.stringValue)) else { continue }
                print(" - got through")
                
                if let doubleValue = try? otherContainer.decode(Double.self, forKey: key) {
                    self.numberFields[key.stringValue] = doubleValue
                } else if let stringValue = try? otherContainer.decode(String.self, forKey: key) {
                    self.stringFields[key.stringValue] = stringValue
                } else {
                    // does not account for an array from NRQL functions like uniques(name)
                    print("unable to decode key: \(key)")
                    return
                }
                
                fieldNames.append(key.stringValue)
            }
        }
    }
}
