//
//  ChartSamples.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import Foundation

struct ChartSamples {
    enum DataSize : String {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
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
    
    static func sampleData(faceted: Bool = false, timeseries: Bool = true, comparable: Bool = false, size: DataSize = .medium) -> NrdbResultContainer? {
        let type = faceted ? "Faceted" : ""
        let timeseriesType = timeseries ? "Timeseries" : ""
        let comparableType = comparable ? "Comparable" : ""
        
        return loadFrom(filename: "\(type)\(timeseriesType)\(comparableType)\(size.rawValue)")
    }
    
}
