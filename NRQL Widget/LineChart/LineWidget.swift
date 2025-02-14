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
        AppIntentConfiguration(kind: kind, intent: LineConfigAppIntent.self, provider: LineChartProvider()) { entry in
            LineChartWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
