//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/13/24.
//

import SwiftUI
import Charts

struct ConfigurableChartView: View {
    var resultsContainer: NrdbResultContainer {
        config.resultContainer
    }
    var availableChartTypes: [ChartType] {
        config.chartTypes
    }

    var hideConfiguration: Bool = false
    
    @State var configShowing: Bool = true
    @State var config: ChartConfiguration
    
    init(config: ChartConfiguration) {
        self.config = config
    }
   
    init(resultsContainer: NrdbResultContainer) {
        let config = ChartConfiguration.init(
            resultContainer: resultsContainer
        )
        self.config = config
    }
    
    var body: some View {
        Section {
            if config.chartType == .line {
                TimeseriesChart(config: config)
            } else if config.chartType == .pie {
                PieChart(config: config)
            } else if config.chartType == .bar {
                BarChart(config: config)
            } else if config.chartType == .table {
                TableChart(config: config)
            } else {
                TimeseriesChart(config: config)
            }
        }
        .inspectorColumnWidth(100)
        .inspector(isPresented: $configShowing) {
            ChartSelector(availableChartTypes: availableChartTypes, selectedChartType: $config.chartType)
            
            if config.chartType == .line {
                TimeseriesChartConfigView(config: $config)
            } else if config.chartType == .pie {
                Text("Pie config goes here")
            } else if config.chartType == .bar {
                Text("Bar config goes here")
            } else if config.chartType == .table {
                Text("Table config goes here")
            } else {
                Text("No additional config")
            }
        }
    }
}

struct ChartSelector: View {
    var availableChartTypes: [ChartType]
    @Binding var selectedChartType: ChartType?
    
    var body: some View {
        Menu {
            ForEach(ChartType.allCases, id: \.self) { option in
                if availableChartTypes.contains(option) {
                    Button(action: { selectedChartType = option }) {
                        Text(option.rawValue)
                    }
                } else {
                    Button(action: {}) {
                        Text(option.rawValue).foregroundColor(.gray)
                    }.disabled(true)
                }
            }
        } label: {
            Text(selectedChartType?.rawValue ?? "Select chart style...")
                .foregroundColor(.primary)
                .padding(.horizontal)
        }
        .padding(.horizontal)
    }
}

#Preview("Timeseries (small)") {
    if let single = ChartSamples.sampleData(size: .small) {
        ConfigurableChartView(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}
//
//#Preview("Basic (small)") {
//    if let single = ChartSamples.sampleData(timeseries: false) {
//        ConfigurableChartView(resultsContainer: single)
//    } else {
//        Text("No sample data")
//    }
//}

#Preview("Faceted (small)") {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false) {
        ConfigurableChartView(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}

#Preview("Faceted Timeseries (small)") {
    if let faceted = ChartSamples.sampleData(facet: .single, size: .small) {
        ConfigurableChartView(resultsContainer: faceted)
    } else {
        Text("No sample data")
    }
}

#Preview("Timeseries (medium)") {
    if let single = ChartSamples.sampleData() {
        ConfigurableChartView(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}

#Preview("Faceted Timeseries (medium)") {
    if let faceted = ChartSamples.sampleData(facet: .single) {
        ConfigurableChartView(resultsContainer: faceted)
    } else {
        Text("No sample data")
    }
}

#Preview("Timeseries comparable (small)") {
    if let single = ChartSamples.sampleData(comparable: true, size: .small) {
        ConfigurableChartView(resultsContainer: single)
    } else {
        Text("No sample data")
    }
}
