//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI
import Charts

struct PieChart: View {
    var config: ChartConfiguration
    
    var resultContainer: NrdbResultContainer {
        config.resultContainer
    }
    
    // this will filter out the unselected facets, they won't be displayed at all
    // the remainder will be filtered into shown/other
    var data: [NrdbResults.MiniDatum] {
        let sortedData = config.resultContainer.results.valuesByFacet(of: selectedField).sorted(using: KeyPathComparator(\.value, order: .reverse))
        var filteredData = sortedData.filter { selectedFacets.contains($0.facet) }
        var otherData: [NrdbResults.MiniDatum] = []
        
        if filteredData.count > config.pie.otherThreshold {
            otherData = Array(
                sortedData[(config.pie.otherThreshold-1)..<filteredData.count]
            )
            filteredData = Array(
                sortedData[0..<(config.pie.otherThreshold-1)]
            )
        }
        
        filteredData.append(
            NrdbResults.MiniDatum(
                facet: "other",
                value: otherData.map{ $0.value }.reduce(0.0, +)
            )
        )
        
        return filteredData
    }
    var metadata: NrdbMetadata { config.resultContainer.metadata }
    
    var selectedFacets: [String] { config.facets.selected }
    var selectedFields: [String] { config.selectedFields }
    
    var selectedField : String {
        guard !selectedFields.isEmpty else { return "" }
        return selectedFields.first!
    }

    var body: some View {
        HStack {
            Chart(data) { datum in
                if selectedFacets.contains(datum.facet) {
                    SectorMark(
                        angle: .value( datum.facet, datum.value ),
                        innerRadius: .ratio(config.pie.isDonut ? 0.5 : 0),
                        angularInset: (config.pie.isSeparated ? 1.5 : 0)
                    )
                    .cornerRadius(2)
                    .foregroundStyle(by: .value(datum.facet, datum.facet))
                } else {
                    SectorMark(
                        angle: .value( "other", datum.value ),
                        innerRadius: .ratio(config.pie.isDonut ? 0.5 : 0),
                        angularInset: (config.pie.isSeparated ? 1.5 : 0)
                    )
                    .cornerRadius(2)
                    .foregroundStyle(by: .value("other", "other"))
                }
                
            }
        }
    }
    
}

struct ConfigView : View {
    @Binding var config: ChartConfiguration
    
    var body : some View {
        GroupBox {
            HStack {
                if config.fields.count > 1 {
                    SeriesSelectionView(title: "Select field...", fields: $config.fields, singleValue: true)
                } else { Text("fields?") }
                if config.facets.all.count > 1 {
                    SeriesSelectionView(title: "Select facets...", fields: $config.facets.all)
                } else { Text("facets?") }
            }
        }
    }
}

#Preview("Single facet (small)") {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, comparable: false, size: .small) {
        Text("data \(single.results.data.count)")
        PieChart(config: .init(resultContainer: single))
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .single, timeseries: false, comparable: false, size: .small))
    }
}

#Preview("Single facet (medium)") {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, comparable: false, size: .medium) {
        Text("data \(single.results.data.count)")
        PieChart(config: .init(resultContainer: single))
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .single, timeseries: false, comparable: false, size: .medium))
    }
}

#Preview("Double facet (small)") {
    if let double = ChartSamples.sampleData(facet: .multi, timeseries: false, comparable: false, size: .small) {
        PieChart(config: .init(resultContainer: double))
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .multi, timeseries: false, comparable: false, size: .small))
    }
}
