//
//  NRQL_Viewer.swift
//  NRQL Viewer
//
//  Created by Eric Baur on 10/12/24.
//

import WidgetKit
import SwiftUI
import AppIntents

struct BillboardChartProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BillboardChartEntry {
        BillboardChartEntry(
            resultContainer: ChartSamples.randomSample(),
            configuration: BillboardConfigAppIntent()
        )
    }
    
    func snapshot(for configuration: BillboardConfigAppIntent, in context: Context) async -> BillboardChartEntry {
        BillboardChartEntry(
            resultContainer: ChartSamples.randomSample(for: .billboard),
            configuration: configuration
        )
    }
    
    func timeline(for configuration: BillboardConfigAppIntent, in context: Context) async -> Timeline<BillboardChartEntry> {
        var entries: [BillboardChartEntry] = []
        let queries = Queries(
            host: configuration.apiHost,
            apiKey: configuration.apiKey,
            accountIds: configuration.accountIds
        )
        let resultContainer = await queries.getNrqlData(query: configuration.nrqlQuery, debug: true)
        guard let resultContainer else {
            let entry = BillboardChartEntry(
                comment: configuration.nrqlQuery,
                configuration: configuration
            )
            return Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: 60*5)))
        }
            
        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let entryDate = Date.now
        let entry = BillboardChartEntry(
            date: entryDate,
            resultContainer: resultContainer,
            configuration: configuration
        )
        entries.append(entry)

        return Timeline(entries: entries, policy: .after(Date(timeIntervalSinceNow: 60*5)))
    }
}

struct BillboardChartEntry: TimelineEntry {
    var date: Date = Date.now
    var comment: String?
    var resultContainer: NrdbResultContainer?
    let configuration: BillboardConfigAppIntent
}
