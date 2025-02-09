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
    
    var data: [NrdbResults.Datum] { config.resultContainer.results.data }
    var metadata: NrdbMetadata { config.resultContainer.metadata }
    
    var selectedFacets: [String] { config.facets.selected }
    var selectedFields: [String] { config.selectedFields }

    func facet(for datum: NrdbResults.Datum) -> String {
        if let facet = datum.facet {
            return facet
        } else if let facets = datum.facets {
            return facets.joined(separator:", ")
        } else {
            return ""
        }
    }

    var body: some View {
        HStack {
            Chart(data.filter { $0.facet == nil || selectedFacets.contains($0.facet!)}) { datum in
                
                ForEach(selectedFields.indices, id: \.self) { index in
                    SectorMark(
                        angle: .value(
                            facet(for: datum),
                            datum.numberFields[selectedFields[index]]!
                        ),
                        innerRadius: .ratio(config.pie.isDonut ? 0.5 : 0),
                        angularInset: (config.pie.isSeparated ? 1.5 : 0)
                    )
                    .opacity(0.5)
                    .cornerRadius(2)
                    .foregroundStyle(by: .value(facet(for: datum), facet(for: datum)))
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
