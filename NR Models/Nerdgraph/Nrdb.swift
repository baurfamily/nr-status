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

// note: only implementing Decodable now, don't think I care about encoding
struct NrdbResultContainer : Decodable {
    enum CodingKeys : String, CodingKey {
        case nrql, results, metadata
    }
    var nrql: String
    var results: NrdbResults
    var metadata: NrdbMetadata
    
    static var empty: NrdbResultContainer {
        return .init()
    }
    
    var data: [NrdbResults.Datum] {
        return results.data
    }
    
    var isEvents: Bool { results.data.first?.isEvent ?? false }
    var isTimeseries: Bool { results.data.first?.isTimeseries ?? false }
    var isFaceted: Bool { results.data.first?.isFaceted ?? false }
    var isMultiFaceted: Bool { results.data.first?.isMultiFaceted ?? false }
    var isComparable: Bool { results.data.first?.isComparable ?? false }
    
    var fieldNames: [String] {
        var names: Set<String> = []
        let sampleSize = results.data.count
        
        results.data[0..<sampleSize].forEach { names.formUnion($0.fieldNames) }
        
        return Array(names)
    }
    
    var numberFieldNames: [String] {
        guard !results.data.isEmpty else { return [] }
        var names: Set<String> = []
        
        results.data.forEach { names.formUnion($0.numberFields.keys) }
        
        return Array(names)
    }
    
    var allFacets: Set<String> {
        // does not deal with array facet
        if isFaceted {
            return Set<String>(results.data.map { $0.facet! })
        } else {
            return []
        }
    }
    var minDate: Date {
        return results.data.filter{ $0.comparison == .current }.map{ $0.beginTime ?? .distantPast }.min()!
    }
    var maxDate: Date {
        return results.data.filter{ $0.comparison == .current }.map{ $0.endTime ?? .distantFuture }.max()!
    }
    
    var dateAdjustment: TimeInterval {
        return minDate.timeIntervalSince1970 - data.filter{ $0.comparison == .previous }.map{ $0.beginTime ?? .distantPast }.min()!.timeIntervalSince1970
    }
    
    func adjustedTime(_ date: Date) -> Date {
        return date.addingTimeInterval(dateAdjustment)
    }
    
    private init() {
        self.nrql = ""
        self.results = NrdbResults(data: [])
        self.metadata = NrdbMetadata(timeWindow: nil, facets: nil)
    }
    
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
    var timeWindow: TimeWindow?
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
    
    var groupedByFacet: [String:[Datum]] {
        Dictionary(grouping: data, by: { $0.facet ?? "" })
    }
    func valuesByFacet(of field: String) -> [MiniDatum] {
        groupedByFacet.mapValues { values in
            values.reduce(0) { $0 + ($1.numberFields[field] ?? 0) }
        }.map { key, value in MiniDatum(field: field, facet: key, value: value) }
    }
    
    struct MiniDatum: Identifiable {
        var id: String { "\(field)-\(facet ?? "")" }
        
        let field: String
        let facet: String?
        let value: Double
    }
    struct StatDatum: Identifiable {
        var id: String { "\(facet)(\(x),\(y),\(z))" }
        
        let facet: String
        let x: Double
        let y: Double
        let z: Double
    }
    
    struct Datum : Decodable, Identifiable {
        enum CodingKeys : String, CodingKey, CaseIterable {
            case beginTimeSeconds, endTimeSeconds, timestamp, facet, comparison
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
        
        // not sure how efficient this is
        var id: String {
            if let beginTime {
                return String(beginTime.timeIntervalSince1970)+(isComparable ? "-\(comparison)" : "")
            } else if let timestamp {
                return String(timestamp.timeIntervalSince1970)+(isComparable ? "-\(comparison)" : "")
            } else {
                return fieldNames.map { field in
                    if let value = numberFields[field] {
                        return String(format: "%.6f", value)
                    } else if let value = stringFields[field] {
                        return value
                    } else {
                        return "unknown_datatype"
                    }
                }.joined(separator: "-")
            }
        }
        
        var isFaceted: Bool { facet != nil }
        var isMultiFaceted: Bool { facets != nil }
        var isTimeseries: Bool { beginTime != nil && endTime != nil }
        var isEvent: Bool { timestamp != nil }
        
        // these will only show up if the data is a TIMESERIES
        var beginTime: Date?
        var endTime: Date?
        // this shows up if we're looking at event data
        var timestamp: Date?
        
        // this isn't adjusted for conmparison data sets
        // useful is we don't care about overlaid graphs
        var date: Date { isEvent ? timestamp! : beginTime! }
        
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
        var stringArrayFields: [String:[String]] = [:]
        var numericArrayFields: [String:[Double]] = [:]
        
        // currently I'm only aware of percentiles using this
        var numericDictFields: [String:[String:Double]] = [:]
        
        // in theory this could be dynamic, but currently it's filled by the decoder
        var fieldNames: [String] = []
        
        init(from decoder : Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if let timestamp = try container.decodeIfPresent(Double.self, forKey: .timestamp) {
                self.timestamp = Date(timeIntervalSince1970: timestamp)
            }
            if let beginTimeSeconds = try container.decodeIfPresent(Double.self, forKey: .beginTimeSeconds) {
                self.beginTime = Date(timeIntervalSince1970: beginTimeSeconds)
            }
            if let endTimeSeconds = try container.decodeIfPresent(Double.self, forKey: .endTimeSeconds) {
                self.endTime = Date(timeIntervalSince1970: endTimeSeconds)
            }
            
            // if the comparison key is not present, we leave the default
            if container.allKeys.contains(.comparison) {
                self.isComparable = true
                self.comparison = try container.decode(Comparison.self, forKey: .comparison)
            }
            
            // for now, we store a single facet differently than a multi-facet
            if let facet = try? container.decodeIfPresent(String.self, forKey: .facet) {
                self.facet = facet
            } else if let facets = try? container.decodeIfPresent([String].self, forKey: .facet) {
                self.facets = facets
            }
            
            let otherContainer = try decoder.container(keyedBy: UnknownCodingKey.self)
            let knownKeys = CodingKeys.allCases.map { $0.stringValue }
            
            // take the remainder and stuff it into a dictionaries
            for key in otherContainer.allKeys {
                guard (!knownKeys.contains(key.stringValue)) else { continue }
                
                if let doubleValue = try? otherContainer.decode(Double.self, forKey: key) {
                    self.numberFields[key.stringValue] = doubleValue
                } else if let stringValue = try? otherContainer.decode(String.self, forKey: key) {
                    self.stringFields[key.stringValue] = stringValue
                } else if let arrayValue = try? otherContainer.decode(Array<Double>.self, forKey: key) {
                    self.numericArrayFields[key.stringValue] = arrayValue
                } else if let arrayValue = try? otherContainer.decode(Array<String>.self, forKey: key) {
                    self.stringArrayFields[key.stringValue] = arrayValue
                } else if let dictValue = try? otherContainer.decode(Dictionary<String,Double>.self, forKey: key) {
                    self.numericDictFields[key.stringValue] = dictValue
                } else {
                    // does not account for an array from NRQL functions like uniques(name)
                    return
                }
                
                fieldNames.append(key.stringValue)
            }
        }
        
        
    }
}
