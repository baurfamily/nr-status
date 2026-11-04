//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct PieWidget: Widget {
    let kind: String = "NRQL Pie Chart"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PieConfigAppIntent.self,
            provider: NrqlChartProvider<PieConfigAppIntent>(chartType: .pie)
        ) { entry in
            NrqlChartWidgetView(
                entry: entry,
                configure: { config, intent in
                    config.pie.isDonut = intent.isDonut
                    config.pie.otherThreshold = intent.numFacets
                },
                chart: { config in PieChart(config: config) }
            )
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
