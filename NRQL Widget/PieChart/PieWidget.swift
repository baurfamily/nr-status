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
        AppIntentConfiguration(kind: kind, intent: PieConfigAppIntent.self, provider: PieChartProvider()) { entry in
            PieChartWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
