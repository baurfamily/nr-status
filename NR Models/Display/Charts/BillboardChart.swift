//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI
import Charts

struct BillboardChart: View {
    var config: ChartConfiguration
    
    var resultContainer: NrdbResultContainer {
        config.resultContainer
    }
    
    var data: [NrdbResults.MiniDatum] {
        config.resultContainer.results.data.flatMap { datum in
            config.selectedFields.map { field in
                NrdbResults.MiniDatum(
                    facet: field,
                    value: datum.numberFields[field] ?? 0
                )
            }
        }
    }
    
    var metadata: NrdbMetadata { config.resultContainer.metadata }
    
    var selectedFacets: [String] { config.facets.selected }
    var selectedFields: [String] { config.selectedFields }
    
    var selectedField : String {
        guard !selectedFields.isEmpty else { return "" }
        return selectedFields.first!
    }

    let columns = [
        GridItem(.adaptive(minimum: 200))
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 50) {
            ForEach(data, id: \.facet) { item in
                BillboardTile(datum: item)
            }
        }
        .padding(.horizontal)
    }
}

struct BillboardTile : View {
    let datum: NrdbResults.MiniDatum
    
    var body: some View {
        VStack {
            Text(datum.value, format: .number.notation(.compactName).precision(.significantDigits(2)))
                .fontWidth(.expanded)
                .font(.system(size: 60, weight: .bold))
            Text(datum.facet)
                .font(.system(size: 20))
                .fontWidth(.condensed)
        }
        .minimumScaleFactor(0.01)
    }
}

#Preview("Single facet (tiny)", traits: .fixedLayout(width: 300, height: 300)) {
    Group {
        if let single = ChartSamples.sampleData(timeseries: false, size: .tiny, statistics: true) {
            Text(".................. poor mans width ...................")
            BillboardChart(config: .init(resultContainer: single))
        } else {
            Text("No sample data")
        }
    }
}

#Preview("Single facet (medium)") {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, comparable: false, size: .medium) {
        Text("data \(single.results.data.count)")
        BillboardChart(config: .init(resultContainer: single))
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .single, timeseries: false, comparable: false, size: .medium))
    }
}

#Preview("Double facet (small)") {
    if let double = ChartSamples.sampleData(facet: .multi, timeseries: false, comparable: false, size: .small) {
        BillboardChart(config: .init(resultContainer: double))
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .multi, timeseries: false, comparable: false, size: .small))
    }
}
