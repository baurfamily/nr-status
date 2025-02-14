//
//  ConfigurationAppIntent.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import AppIntents

struct PieConfigAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "NRQL Pie Chart" }
    static var description: IntentDescription { "This widget allows you to view a pie graph built from a NRQL query." }
    
    @Parameter(title: "API Host", default: "api.newrelic.com")
    var apiHost: String
    
    @Parameter(title: "API Key", default: "NRAK-")
    var apiKey: String
    
    @Parameter(title: "Account IDs", default: "")
    var accountIds: String
    
    @Parameter(title: "Title", default: "NRQL Viewer")
    var title: String
    
    @Parameter(title: "NRQL Query", default: "SELECT count(*) FROM Transaction FACET http.statusCode SINCE 6 hours ago")
    var nrqlQuery: String
    
    @Parameter(title: "Show Legend", default: false)
    var showLegend: Bool
    
    @Parameter(title: "Donut", default: true)
    var isDonut: Bool
    
    @Parameter(title: "# of facets", default: 10)
    var numFacets: Int
}
