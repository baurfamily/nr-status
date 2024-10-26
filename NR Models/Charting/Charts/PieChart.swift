//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI
import Charts

struct PieChart: View {
    var resultsContainer: NrdbResultContainer
    @State var config: ChartConfiguration

    var data: [NrdbResults.Datum] { resultsContainer.results.data }
    var metadata: NrdbMetadata { resultsContainer.metadata }
    
    var selectedFacets: [String] { config.selectedFacets }
    var selectedFields: [String] { config.selectedFields }

    init(resultsContainer: NrdbResultContainer) {
        self.resultsContainer = resultsContainer
        
        var fields: [SelectableField] = []
        var facets: [SelectableField] = []
        
        if let first = resultsContainer.results.data.first {
            fields = SelectableField.wrap( first.numberFields.keys.sorted() )
            fields[0].isSelected = true
        }
        facets = SelectableField.wrap( resultsContainer.allFacets.sorted() )
                
        self.config = .init(
            isStacked: false,
            isSmoothed: true,
            showDataPoints: false,
            fields: fields,
            facets: facets
        )
    }
    
    /*
     0 => 0, 0.5
     1 => 0.5, 1
     
     section size: 1/count
     inner = 0 + index * 1/count
     outer = 1 - (count-index) * 1/count
     
     0 => 0, .33
     1 => .33, .66
     2 => .66, 1
    */
    // this was all a feeble attempt to support coencentric donut charts
    // but that isn't actually supported by swift charts :(
    // leaving this here for now in case I want to return to it...
    func innerRadius(_ index: Int) -> CGFloat {
        return Double(index) * 1.0/Double(selectedFields.count)
    }
    func outerRadius(_ index: Int) -> CGFloat {
        return Double(index+1) * 1.0/Double(selectedFields.count)
    }

    var body: some View {
        ConfigView(config: $config)
        
        HStack {
            Chart(data.filter { $0.facet == nil || selectedFacets.contains($0.facet!)}) { datum in
                
                ForEach(selectedFields.indices, id: \.self) { index in
                    SectorMark(
                        angle: .value(
                            datum.facet!,
                            datum.numberFields[selectedFields[index]]!
                        ),
//                        innerRadius: .ratio(innerRadius(index)),
//                        outerRadius: .ratio(outerRadius(index)),
                        angularInset: 1.5
                    )
                    .opacity(0.5)
                    .cornerRadius(2)
                    .foregroundStyle(by: .value(datum.facet!, datum.facet!))
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
                    SeriesSelectionView(title: "Select fields...", fields: $config.fields, singleValue: true)
                } else { Text("fields?") }
                if config.facets.count > 1 {
                    SeriesSelectionView(title: "Select facets...", fields: $config.facets)
                } else { Text("facets?") }
            }
        }
    }
}



#Preview("Single facet (small)") {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, comparable: false, size: .small) {
        Text("data \(single.results.data.count)")
        PieChart(resultsContainer: single)
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .single, timeseries: false, comparable: false, size: .small))
    }
}

#Preview("Single facet (medium)") {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, comparable: false, size: .medium) {
        Text("data \(single.results.data.count)")
        PieChart(resultsContainer: single)
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .single, timeseries: false, comparable: false, size: .medium))
    }
}

#Preview("Double facet (small)") {
    if let double = ChartSamples.sampleData(facet: .multi, timeseries: false, comparable: false, size: .small) {
        PieChart(resultsContainer: double)
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .multi, timeseries: false, comparable: false, size: .small))
    }
}
