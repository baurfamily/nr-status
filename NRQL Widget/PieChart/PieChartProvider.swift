//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI

struct PieChartProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PieChartEntry {
        PieChartEntry(
            resultContainer: ChartSamples.randomSample(),
            configuration: PieConfigAppIntent()
        )
    }

    func snapshot(for configuration: PieConfigAppIntent, in context: Context) async -> PieChartEntry {
        PieChartEntry(
            resultContainer: ChartSamples.randomSample(for: .pie),
            configuration: PieConfigAppIntent()
        )
    }
    
    func timeline(for configuration: PieConfigAppIntent, in context: Context) async -> Timeline<PieChartEntry> {
        var entries: [PieChartEntry] = []
        let queries = Queries(
            host: configuration.apiHost,
            apiKey: configuration.apiKey,
            accountIds: configuration.accountIds
        )
        let resultContainer = await queries.getNrqlData(query: configuration.nrqlQuery, debug: true)
        guard let resultContainer else {
            let entry = PieChartEntry(
                comment: configuration.nrqlQuery,
                configuration: configuration
            )
            return Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: 60*5)))
        }
            
        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let entryDate = Date.now
        let entry = PieChartEntry(
            date: entryDate,
            resultContainer: resultContainer,
            configuration: configuration
        )
        entries.append(entry)

        return Timeline(entries: entries, policy: .after(Date(timeIntervalSinceNow: 60*5)))
    }
}

struct PieChartEntry: TimelineEntry {
    var date: Date = Date.now
    var comment: String?
    var resultContainer: NrdbResultContainer?
    let configuration: PieConfigAppIntent
}
