//
//  ChartSamples.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import Foundation

struct ChartSamples {
    enum DataSize : String, CaseIterable {
        case tiny = "Tiny"
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
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
        case 0: return sampleData(size: .medium)
        case 1: return sampleData(size: .small)
        case 2: return sampleData(facet: .single, size: .medium)
        case 3: return sampleData(facet: .single, size: .small)
        case 4: return sampleData(facet: .single, size: .medium)
        case 5: return sampleData(facet: .single, size: .small)
        default: return sampleData()
        }
    }
    
    static func randomSample(for chartType: ChartType) -> NrdbResultContainer? {
        switch (chartType) {
        case .pie: return [
            sampleData(facet: .single, timeseries: false, size: .small)!,
            sampleData(facet: .single, timeseries: false, size: .medium)!,
        ].randomElement()
        case .bar: return [
            sampleData(facet: .single, timeseries: false, size: .small)!,
            sampleData(facet: .single, timeseries: false, size: .medium)!,
        ].randomElement()
        case .billboard: return sampleData(timeseries: false, size: .tiny, statistics: false)
        case .plot: return sampleData(facet: .single, size: .medium)
        default: return randomSample()
        }
    }
    
    static func sampleFilename(facet: FacetType = .none, timeseries: Bool = true, comparable: Bool = false, size: DataSize = .medium, statistics: Bool = false) -> String {
        let timeseriesType = timeseries ? "Timeseries" : ""
        let comparableType = comparable ? "Comparable" : ""
        let statsType = statistics ? "Stats" : ""
        
        return "\(facet.rawValue)\(timeseriesType)\(comparableType)\(statsType)\(size.rawValue)"
    }
    
    static func sampleData(facet: FacetType = .none, timeseries: Bool = true, comparable: Bool = false, size: DataSize = .medium, statistics: Bool = false) -> NrdbResultContainer? {
        let timeseriesType = timeseries ? "Timeseries" : ""
        let comparableType = comparable ? "Comparable" : ""
        let statsType = statistics ? "Stats" : ""
        
        return loadFrom(filename: "\(facet.rawValue)\(timeseriesType)\(comparableType)\(statsType)\(size.rawValue)")
    }
    
}
