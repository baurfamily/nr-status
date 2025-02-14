//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct PieChartWidgetView : View {
    var entry: PieChartProvider.Entry
    
    func configuration() -> ChartConfiguration? {
        guard let results = entry.resultContainer else { return nil }
        var config = ChartConfiguration.init(resultContainer: results)
        
        config.pie.isDonut = entry.configuration.isDonut
        config.pie.otherThreshold = entry.configuration.numFacets
        
        return config
    }
    
    var body: some View {
        if let config = configuration() {
            Text(entry.configuration.title)

            PieChart(config: config)
                .chartLegend(entry.configuration.showLegend ? .visible : .hidden)
        } else {
            Text("Error loading data")
        }
    }
}
