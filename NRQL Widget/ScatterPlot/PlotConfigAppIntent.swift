//
//  ConfigurationAppIntent.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import AppIntents

struct PlotConfigAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "NRQL Scatter Plot" }
    static var description: IntentDescription { "This widget allows you to view a Plot graph built from a NRQL query." }
    
    @Parameter(title: "API Host", default: "api.newrelic.com")
    var apiHost: String
    
    @Parameter(title: "API Key", default: "NRAK-")
    var apiKey: String
    
    @Parameter(title: "Account IDs", default: "")
    var accountIds: String
    
    @Parameter(title: "Title", default: "NRQL Scatter Plot")
    var title: String
    
    @Parameter(title: "NRQL Query", default: "FROM Transaction SELECT 1000*databaseDuration AS 'database_ms', 1000*duration AS 'duration_ms', databaseCallCount WHERE databaseCallCount is NOT NULL SINCE 1 month ago")
    var nrqlQuery: String
    
    @Parameter(title: "Show Legend", default: false)
    var showLegend: Bool
}
