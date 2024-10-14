//
//  AppIntent.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "NRQL Viewer" }
    static var description: IntentDescription { "This widget allows you to view a graph built from a NRQL query." }

    @Parameter(title: "API Host", default: "api.newrelic.com")
    var apiHost: String
    
    @Parameter(title: "API Key", default: "NRAK-")
    var apiKey: String
    
    @Parameter(title: "Account IDs", default: "")
    var accountIds: String
    
    @Parameter(title: "Title", default: "NRQL Viewer")
    var title: String
    
    // An example configurable parameter.
    @Parameter(title: "NRQL Query", default: "SELECT count(*) FROM Transaction FACET http.statusCode SINCE 6 hours ago TIMESERIES 15 minutes")
    var nrqlQuery: String
}
