//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            resultContainer: ChartSamples.randomSample(),
            configuration: ConfigurationAppIntent()
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(
            resultContainer: ChartSamples.randomSample(),
            configuration: ConfigurationAppIntent()
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        let queries = Queries(
            host: configuration.apiHost,
            apiKey: configuration.apiKey,
            accountIds: configuration.accountIds
        )
        let resultContainer = await queries.getNrqlData(query: configuration.nrqlQuery, debug: true)
        guard let resultContainer else {
            let entry = SimpleEntry(
                comment: configuration.nrqlQuery,
                configuration: configuration
            )
            return Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: 10)))
        }
            
        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let entryDate = Date.now
        let entry = SimpleEntry(
            date: entryDate,
            resultContainer: resultContainer,
            configuration: configuration
        )
        entries.append(entry)

        return Timeline(entries: entries, policy: .after(Date(timeIntervalSinceNow: 60)))
    }

//    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct SimpleEntry: TimelineEntry {
    var date: Date = Date.now
    var comment: String?
    var resultContainer: NrdbResultContainer?
    let configuration: ConfigurationAppIntent
}

struct NRQL_ViewerEntryView : View {
    var entry: Provider.Entry
    
    @State var resultContainer: NrdbResultContainer?

    var body: some View {
        if let resultContainer = entry.resultContainer {
            Text(entry.configuration.title)
            TimeseriesChart(resultsContainer: resultContainer)
                .chartLegend(.hidden)
        } else {
            Text("Error loading data")
        }
    }
}

struct NRQL_Viewer: Widget {
    let kind: String = "NRQL_Viewer"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            NRQL_ViewerEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
