//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct PlotChartWidgetView : View {
    var entry: PlotChartProvider.Entry
    
    func configuration() -> ChartConfiguration? {
        guard let results = entry.resultContainer else { return nil }
        let config = ChartConfiguration.init(resultContainer: results)
        
        return config
    }
    
    var body: some View {
        if let config = configuration() {
            Text(entry.configuration.title)

            ScatterPlot(config: config)
                .chartLegend(entry.configuration.showLegend ? .visible : .hidden)
        } else {
            Text("Error loading data")
        }
    }
}
