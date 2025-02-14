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
        AppIntentConfiguration(kind: kind, intent: BillboardConfigAppIntent.self, provider: BillboardChartProvider()) { entry in
            BillboardChartWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
