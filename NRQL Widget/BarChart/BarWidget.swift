//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct BarWidget: Widget {
    let kind: String = "NRQL Bar Chart"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: BarConfigAppIntent.self,
            provider: NrqlChartProvider<BarConfigAppIntent>(chartType: .bar)
        ) { entry in
            NrqlChartWidgetView(
                entry: entry,
                configure: { config, intent in
                    config.bar.pivotData = intent.pivotData
                },
                chart: { config in BarChart(config: config) }
            )
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
