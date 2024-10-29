//
//  ChartSelectionView.swift
//  NR Status
//
//  Created by Eric Baur on 10/23/24.
//

import SwiftUI
import Charts

struct ChartSelectionView: View {
    let resultsContainer: NrdbResultContainer
    let availableChartTypes: [ChartType]
    
    @State var config: ChartConfiguration
    
    init(resultsContainer: NrdbResultContainer) {
        self.resultsContainer = resultsContainer
        
        var fields: [SelectableField] = []
        var facets: [SelectableField] = []
        
        if let first = resultsContainer.results.data.first {
            fields = SelectableField.wrap( first.numberFields.keys.sorted() )
        }
        facets = SelectableField.wrap( resultsContainer.allFacets.sorted() )
        
        var config = ChartConfiguration.init(
            isStacked: false,
            isSmoothed: true,
            showDataPoints: false,
            fields: fields,
            facets: facets
        )
        availableChartTypes = config.chartTypeFor(results: resultsContainer)
        config.chartType = availableChartTypes.first
        self.config = config
    }
    
    var body: some View {
        Menu {
            ForEach(ChartType.allCases, id: \.self) { option in
                if availableChartTypes.contains(option) {
                    Button(action: { config.chartType = option }) {
                        Text(option.rawValue)
                    }
                } else {
                    Button(action: {}) {
                        Text(option.rawValue).foregroundColor(.gray)
                    }.disabled(true)
                }
            }
        } label: {
            Text(config.chartType?.rawValue ?? "Select chart style...")
                .foregroundColor(.primary)
                .padding(.horizontal)
        }
       .padding(.horizontal)
        
        if config.chartType == .line {
            TimeseriesChart(resultsContainer: resultsContainer, config: config)
        } else if config.chartType == .pie {
            PieChart(resultsContainer: resultsContainer)
        } else if config.chartType == .bar {
            BarChart(resultsContainer: resultsContainer)
        } else if config.chartType == .table {
            TableChart(resultsContainer: resultsContainer)
        }
    }
}

#Preview {
    VStack {
        ChartSampleView()
    }.frame(width: 500, height: 600)
}
