//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct LineChartProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LineChartEntry {
        LineChartEntry(
            resultContainer: ChartSamples.randomSample(),
            configuration: LineConfigAppIntent()
        )
    }

    func snapshot(for configuration: LineConfigAppIntent, in context: Context) async -> LineChartEntry {
        LineChartEntry(
            resultContainer: ChartSamples.randomSample(),
            configuration: LineConfigAppIntent()
        )
    }
    
    func timeline(for configuration: LineConfigAppIntent, in context: Context) async -> Timeline<LineChartEntry> {
        var entries: [LineChartEntry] = []
        let queries = Queries(
            host: configuration.apiHost,
            apiKey: configuration.apiKey,
            accountIds: configuration.accountIds
        )
        let resultContainer = await queries.getNrqlData(query: configuration.nrqlQuery, debug: true)
        guard let resultContainer else {
            let entry = LineChartEntry(
                comment: configuration.nrqlQuery,
                configuration: configuration
            )
            return Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: 60*5)))
        }
            
        let entryDate = Date.now
        let entry = LineChartEntry(
            date: entryDate,
            resultContainer: resultContainer,
            configuration: configuration
        )
        entries.append(entry)

        return Timeline(entries: entries, policy: .after(Date(timeIntervalSinceNow: 60*5)))
    }
}

struct LineChartEntry: TimelineEntry {
    var date: Date = Date.now
    var comment: String?
    var resultContainer: NrdbResultContainer?
    let configuration: LineConfigAppIntent
}
