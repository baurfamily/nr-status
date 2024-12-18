//
//  ChartSamples.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import Foundation

struct ChartSamples {
    enum DataSize : String, CaseIterable {
        case small = "Small"
        case medium = "Medium"
//        case large = "Large"
    }
    enum FacetType : String, CaseIterable {
        case none = ""
        case single = "Faceted"
        case multi = "MultiFaceted"
    }
    
    static func loadFrom(filename: String) -> NrdbResultContainer? {
        // Load and decode the JSON.
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            print("Failed to find \(filename).json")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let root = try JSONDecoder().decode(Root.self, from: data)
            
            return root.data?.actor?.nrql
        } catch {
            print("Failed to load sample data from \(filename).json: \(error)")
        }
        return nil
    }
    
    static func randomSample() -> NrdbResultContainer? {
        switch Int.random(in: 0..<6) {
        case 0: return ChartSamples.sampleData(size: .medium)
        case 1: return ChartSamples.sampleData(size: .small)
        case 2: return ChartSamples.sampleData(facet: .single, size: .medium)
        case 3: return ChartSamples.sampleData(facet: .single, size: .small)
        case 4: return ChartSamples.sampleData(facet: .single, size: .medium)
        case 5: return ChartSamples.sampleData(facet: .single, size: .small)
        default: return ChartSamples.sampleData()
        }
    }
    
    static func sampleFilename(facet: FacetType = .none, timeseries: Bool = true, comparable: Bool = false, size: DataSize = .medium) -> String {
        let timeseriesType = timeseries ? "Timeseries" : ""
        let comparableType = comparable ? "Comparable" : ""
        
        return "\(facet.rawValue)\(timeseriesType)\(comparableType)\(size.rawValue)"
    }
    
    static func sampleData(facet: FacetType = .none, timeseries: Bool = true, comparable: Bool = false, size: DataSize = .medium) -> NrdbResultContainer? {
        let timeseriesType = timeseries ? "Timeseries" : ""
        let comparableType = comparable ? "Comparable" : ""
        
        return loadFrom(filename: "\(facet.rawValue)\(timeseriesType)\(comparableType)\(size.rawValue)")
    }
    
}
