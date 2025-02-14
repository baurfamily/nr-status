//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct LineChartWidgetView : View {
    var entry: LineChartProvider.Entry
    
    func configuration() -> ChartConfiguration? {
        guard let results = entry.resultContainer else { return nil }
        var config = ChartConfiguration.init(resultContainer: results)
        
        config.timeseries.isSmoothed = entry.configuration.isSmoothed
        config.timeseries.isStacked = entry.configuration.isStacked
        config.timeseries.showDataPoints = entry.configuration.showDataPoints
        
        return config
    }
    
    var body: some View {
        if let config = configuration() {
            Text(entry.configuration.title)

            TimeseriesChart(config: config)
                .chartLegend(entry.configuration.showLegend ? .visible : .hidden)
        } else {
            Text("Error loading data")
        }
    }
}
