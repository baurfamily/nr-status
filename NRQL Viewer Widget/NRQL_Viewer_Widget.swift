//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NrdbResultEntry {
        NrdbResultEntry(
            resultContainer: ChartSamples.randomSample(),
            configuration: ConfigurationAppIntent()
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> NrdbResultEntry {
        NrdbResultEntry(
            resultContainer: ChartSamples.randomSample(),
            configuration: ConfigurationAppIntent()
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<NrdbResultEntry> {
        var entries: [NrdbResultEntry] = []
        let queries = Queries(
            host: configuration.apiHost,
            apiKey: configuration.apiKey,
            accountIds: configuration.accountIds
        )
        let resultContainer = await queries.getNrqlData(query: configuration.nrqlQuery, debug: true)
        guard let resultContainer else {
            let entry = NrdbResultEntry(
                comment: configuration.nrqlQuery,
                configuration: configuration
            )
            return Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: 60*5)))
        }
            
        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let entryDate = Date.now
        let entry = NrdbResultEntry(
            date: entryDate,
            resultContainer: resultContainer,
            configuration: configuration
        )
        entries.append(entry)

        return Timeline(entries: entries, policy: .after(Date(timeIntervalSinceNow: 60*5)))
    }

//    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct NrdbResultEntry: TimelineEntry {
    var date: Date = Date.now
    var comment: String?
    var resultContainer: NrdbResultContainer?
    let configuration: ConfigurationAppIntent
}

struct NRQL_ViewerEntryView : View {
    var entry: Provider.Entry
    
    @State var resultContainer: NrdbResultContainer?
    
    var fieldsAndFacets: ([SelectableField], [SelectableField]) {
        if let resultContainer {
            return ChartConfiguration.fieldsAndFacets(from: resultContainer)
        } else {
            return ([], [])
        }
    }
    var firstField: String {
        fieldsAndFacets.0.first?.id ?? ""
    }

    var body: some View {
        Text("-----")
        Text(firstField)
        if let resultContainer = entry.resultContainer {
            Text(entry.configuration.title)
            TimeseriesChart(
                resultsContainer: resultContainer,
                config: ChartConfiguration(
                    isStacked: entry.configuration.isStacked,
                    isSmoothed: entry.configuration.isSmoothed,
                    showDataPoints: entry.configuration.showDataPoints,
                    fields: fieldsAndFacets.0,
                    facets: fieldsAndFacets.1
                )
            ).chartLegend(.hidden)
            ChartSelectionView(resultsContainer: resultContainer)//.chartLegend(.hidden)
        } else {
            Text("Error loading data")
        }
    }
}

struct NRQL_Viewer_Widget: Widget {
    let kind: String = "NRQL_Viewer"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            NRQL_ViewerEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
