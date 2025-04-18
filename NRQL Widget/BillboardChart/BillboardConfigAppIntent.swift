//
//  ConfigurationAppIntent.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import AppIntents

struct BillboardConfigAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "NRQL Billboard Chart" }
    static var description: IntentDescription { "This widget allows you to view a Billboard built from a NRQL query." }
    
    @Parameter(title: "API Host", default: "api.newrelic.com")
    var apiHost: String
    
    @Parameter(title: "API Key", default: "NRAK-")
    var apiKey: String
    
    @Parameter(title: "Account IDs", default: "")
    var accountIds: String
    
    @Parameter(title: "Title", default: "NRQL Billboard")
    var title: String
    
    @Parameter(title: "NRQL Query", default: "SELECT count(*) FROM Transaction FACET http.statusCode SINCE 6 hours ago")
    var nrqlQuery: String
    
    @Parameter(title: "Show Legend", default: false)
    var showLegend: Bool
    
    @Parameter(title: "Show gauge", default: false)
    var showGauge: Bool
    
    @Parameter(title: "Gauge Style", default: BillboardConfiguration.GaugeStyle.linear)
    var gaugeStyle: BillboardConfiguration.GaugeStyle
    
    @Parameter(title: "Gauge Max", default: 100)
    var gaugeMax: Double
}
