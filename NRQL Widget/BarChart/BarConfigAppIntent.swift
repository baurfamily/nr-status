//
//  ConfigurationAppIntent.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import AppIntents

struct BarConfigAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "NRQL Bar Chart" }
    static var description: IntentDescription { "This widget allows you to view a Bar graph built from a NRQL query." }
    
    @Parameter(title: "API host", default: "api.newrelic.com")
    var apiHost: String
    
    @Parameter(title: "API key", default: "NRAK-")
    var apiKey: String
    
    @Parameter(title: "Account IDs", default: "")
    var accountIds: String
    
    @Parameter(title: "Title", default: "NRQL Bar Chart")
    var title: String
    
    @Parameter(title: "NRQL query", default: "SELECT count(*) FROM Transaction FACET http.statusCode SINCE 6 hours ago")
    var nrqlQuery: String
    
    @Parameter(title: "Show legend", default: false)
    var showLegend: Bool
    
    @Parameter(title: "Pivot data", default: false)
    var pivotData: Bool
}
