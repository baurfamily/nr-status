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
    let hideConfiguration: Bool
    
    @State var config: ChartConfiguration
    
    init(resultsContainer: NrdbResultContainer, configuration: ChartConfiguration? = nil, hideConfiguration: Bool = false) {
        self.resultsContainer = resultsContainer
        self.hideConfiguration = hideConfiguration
        
        var config: ChartConfiguration
        if let c = configuration {
            config = c
        } else {
            config = ChartConfiguration.init(
                resultContainer: resultsContainer
            )
        }
        availableChartTypes = config.chartTypes
        config.chartType = availableChartTypes.first
        self.config = config
    }
    
    var body: some View {
        if !hideConfiguration {
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
        }
        
        if config.chartType == .line {
            ConfigurableChartView(resultsContainer: resultsContainer, hideConfiguration: hideConfiguration)
        } else if config.chartType == .pie {
            PieChart(config: .init(resultContainer: resultsContainer))
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
