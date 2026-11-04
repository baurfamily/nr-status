//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct BillboardWidget: Widget {
    let kind: String = "NRQL Billboard Chart"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: BillboardConfigAppIntent.self,
            provider: NrqlChartProvider<BillboardConfigAppIntent>(chartType: .billboard)
        ) { entry in
            NrqlChartWidgetView(
                entry: entry,
                configure: { config, intent in
                    config.billboard.showGauge = intent.showGauge
                    config.billboard.gaugeStyle = intent.gaugeStyle
                    config.billboard.gaugeMax = intent.gaugeMax
                },
                chart: { config in BillboardChart(config: config) }
            )
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
