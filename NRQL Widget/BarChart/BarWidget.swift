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
        AppIntentConfiguration(kind: kind, intent: BarConfigAppIntent.self, provider: BarChartProvider()) { entry in
            BarChartWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
