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
        AppIntentConfiguration(kind: kind, intent: PlotConfigAppIntent.self, provider: PlotChartProvider()) { entry in
            PlotChartWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
