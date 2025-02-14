//
//  ConfigurationAppIntent.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import AppIntents

struct LineConfigAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "NRQL Timeseries Chart" }
    static var description: IntentDescription { "This widget allows you to view a line graph built from a Timeseries NRQL query." }
    
    @Parameter(title: "API Host", default: "api.newrelic.com")
    var apiHost: String
    
    @Parameter(title: "API Key", default: "NRAK-")
    var apiKey: String
    
    @Parameter(title: "Account IDs", default: "")
    var accountIds: String
    
    @Parameter(title: "Title", default: "NRQL Line Chart")
    var title: String
    
    @Parameter(title: "NRQL Query", default: "SELECT count(*) FROM Transaction FACET http.statusCode SINCE 6 hours ago TIMESERIES 15 minutes")
    var nrqlQuery: String
    
    @Parameter(title: "Stacked", default: false)
    var isStacked: Bool
    
    @Parameter(title: "Smoothed", default: true)
    var isSmoothed: Bool

    @Parameter(title: "Show Legend", default: false)
    var showLegend: Bool
    
    @Parameter(title: "Show Data Points", default: false)
    var showDataPoints: Bool
}
