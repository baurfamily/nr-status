//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct PlotWidget: Widget {
    let kind: String = "NRQL Plot Chart"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PlotConfigAppIntent.self,
            provider: NrqlChartProvider<PlotConfigAppIntent>(chartType: .plot)
        ) { entry in
            NrqlChartWidgetView(entry: entry) { config in
                ScatterPlot(config: config)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
