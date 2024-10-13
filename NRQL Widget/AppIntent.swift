//
//  AppIntent.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

//    @Parameter(title: "API Host", default: "api.newrelic.com")
//    var apiHost: String
//    
//    @Parameter(title: "API Key", default: "NRAK-")
//    var apiKey: String
    
    // An example configurable parameter.
    @Parameter(title: "NRQL Query", default: "SELECT count(*) FROM Transaction FACET http.statusCode SINCE 6 house ago TIMESERIES 15 minutes")
    var nrqlQuery: String
}
