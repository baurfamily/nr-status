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
            date: Date(),
            resultContainer: ChartSamples.sampleData(timeseries: true, comparable: true, size: .small),
            configuration: ConfigurationAppIntent()
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            resultContainer: ChartSamples.sampleData(timeseries: true, comparable: true, size: .small),
            configuration: ConfigurationAppIntent()
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        // I think you can pre-populate things
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
        let entry = SimpleEntry(
            date: entryDate,
            resultContainer: ChartSamples.sampleData(timeseries: true, comparable: true, size: .small),
            configuration: ConfigurationAppIntent()
        )
        entries.append(entry)

        return Timeline(entries: entries, policy: .atEnd)
    }

//    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let resultContainer: NrdbResultContainer?
    let configuration: ConfigurationAppIntent
}

struct NRQL_ViewerEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        if let resultContainer = entry.resultContainer {
            TimeseriesChart(resultsContainer: resultContainer)
        } else {
            Text("nothing to see here")
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
