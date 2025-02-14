//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct PlotChartProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PlotChartEntry {
        PlotChartEntry(
            resultContainer: ChartSamples.randomSample(),
            configuration: PlotConfigAppIntent()
        )
    }

    func snapshot(for configuration: PlotConfigAppIntent, in context: Context) async -> PlotChartEntry {
        PlotChartEntry(
            resultContainer: ChartSamples.randomSample(for: .plot),
            configuration: PlotConfigAppIntent()
        )
    }
    
    func timeline(for configuration: PlotConfigAppIntent, in context: Context) async -> Timeline<PlotChartEntry> {
        var entries: [PlotChartEntry] = []
        let queries = Queries(
            host: configuration.apiHost,
            apiKey: configuration.apiKey,
            accountIds: configuration.accountIds
        )
        let resultContainer = await queries.getNrqlData(query: configuration.nrqlQuery, debug: true)
        guard let resultContainer else {
            let entry = PlotChartEntry(
                comment: configuration.nrqlQuery,
                configuration: configuration
            )
            return Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: 60*5)))
        }
            
        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let entryDate = Date.now
        let entry = PlotChartEntry(
            date: entryDate,
            resultContainer: resultContainer,
            configuration: configuration
        )
        entries.append(entry)

        return Timeline(entries: entries, policy: .after(Date(timeIntervalSinceNow: 60*5)))
    }
}

struct PlotChartEntry: TimelineEntry {
    var date: Date = Date.now
    var comment: String?
    var resultContainer: NrdbResultContainer?
    let configuration: PlotConfigAppIntent
}
