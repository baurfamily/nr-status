//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct BillboardChartWidgetView : View {
    var entry: BillboardChartProvider.Entry
    
    func configuration() -> ChartConfiguration? {
        guard let results = entry.resultContainer else { return nil }
        var config = ChartConfiguration.init(resultContainer: results)
        
        config.billboard.showGauge = entry.configuration.showGauge
        config.billboard.gaugeStyle = entry.configuration.gaugeStyle
        config.billboard.gaugeMax = entry.configuration.gaugeMax
        
        return config
    }
    
    var body: some View {
        if let config = configuration() {
            Text(entry.configuration.title)

            BillboardChart(config: config)
                .chartLegend(entry.configuration.showLegend ? .visible : .hidden)
        } else {
            Text("Error loading data")
        }
    }
}
