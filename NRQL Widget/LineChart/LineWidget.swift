//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct LineWidget: Widget {
    let kind: String = "NRQL Line Chart"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: LineConfigAppIntent.self,
            provider: NrqlChartProvider<LineConfigAppIntent>(chartType: .line)
        ) { entry in
            NrqlChartWidgetView(
                entry: entry,
                configure: { config, intent in
                    config.timeseries.isSmoothed = intent.isSmoothed
                    config.timeseries.isStacked = intent.isStacked
                    config.timeseries.showDataPoints = intent.showDataPoints
                },
                chart: { config in TimeseriesChart(config: config) }
            )
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
