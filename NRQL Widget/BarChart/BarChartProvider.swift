//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct BarChartProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BarChartEntry {
        BarChartEntry(
            resultContainer: ChartSamples.randomSample(),
            configuration: BarConfigAppIntent()
        )
    }

    func snapshot(for configuration: BarConfigAppIntent, in context: Context) async -> BarChartEntry {
        BarChartEntry(
            resultContainer: ChartSamples.randomSample(for: .bar),
            configuration: BarConfigAppIntent()
        )
    }
    
    func timeline(for configuration: BarConfigAppIntent, in context: Context) async -> Timeline<BarChartEntry> {
        var entries: [BarChartEntry] = []
        let queries = Queries(
            host: configuration.apiHost,
            apiKey: configuration.apiKey,
            accountIds: configuration.accountIds
        )
        let resultContainer = await queries.getNrqlData(query: configuration.nrqlQuery, debug: true)
        guard let resultContainer else {
            let entry = BarChartEntry(
                comment: configuration.nrqlQuery,
                configuration: configuration
            )
            return Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: 60*5)))
        }
            
        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let entryDate = Date.now
        let entry = BarChartEntry(
            date: entryDate,
            resultContainer: resultContainer,
            configuration: configuration
        )
        entries.append(entry)

        return Timeline(entries: entries, policy: .after(Date(timeIntervalSinceNow: 60*5)))
    }
}

struct BarChartEntry: TimelineEntry {
    var date: Date = Date.now
    var comment: String?
    var resultContainer: NrdbResultContainer?
    let configuration: BarConfigAppIntent
}
