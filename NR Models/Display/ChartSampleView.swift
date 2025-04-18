//
//  ChartSampleView.swift
//  NR Status
//
//  Created by Eric Baur on 10/20/24.
//

import SwiftUI

struct ChartSampleView : View {
    @State var facetType: ChartSamples.FacetType = .none
    @State var isTimeseries: Bool = false
    @State var isComparable: Bool = false
    @State var isStats: Bool = false
    @State var size: ChartSamples.DataSize = .small
    
    var resultContainer: NrdbResultContainer? {
        ChartSamples.sampleData(
            facet: facetType,
            timeseries: isTimeseries,
            comparable: isComparable,
            size: size,
            statistics: isStats
        ) ?? nil
    }
    var filename: String {
        ChartSamples.sampleFilename(
            facet: facetType,
            timeseries: isTimeseries,
            comparable: isComparable,
            size: size,
            statistics: isStats
        )
    }
    
    var body: some View {
        VStack {
            HStack {
                Toggle(isOn: $isTimeseries) {
                    Text("Timeseries")
                }
                Toggle(isOn: $isComparable) {
                    Text("Comparable")
                }
                Toggle(isOn: $isStats) {
                    Text("Stats")
                }
                Picker("Facet Type", selection: $facetType) {
                    ForEach(ChartSamples.FacetType.allCases, id: \.rawValue) { encoding in
                        Text(encoding.rawValue).tag(encoding)
                    }
                }
                Picker("Data Size", selection: $size) {
                    ForEach(ChartSamples.DataSize.allCases, id: \.rawValue) { encoding in
                        Text(encoding.rawValue).tag(encoding)
                    }
                }
            }
            GroupBox {
                Text("Potential filename: \(filename)")
            }
        }.frame(alignment: .topLeading)
        
        if let results = resultContainer {
            Text(results.nrql).textSelection(.enabled)
            ConfigurableChartView(resultsContainer: results)
        }
    }
}

#Preview {
    VStack {
        ChartSampleView()
    }.frame(width: 500, height: 600)
}
