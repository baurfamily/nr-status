//
//  NrqlChartWidgetSupport.swift
//  NRQL Widget
//
//  Shared provider, entry and view used by every chart widget.
//

import WidgetKit
import SwiftUI
import AppIntents

/// The settings every NRQL chart widget intent exposes.
protocol NrqlWidgetIntent: WidgetConfigurationIntent {
    var apiHost: String { get }
    var apiKey: String { get }
    var accountIds: String { get }
    var title: String { get }
    var nrqlQuery: String { get }
    var showLegend: Bool { get }
}

struct NrqlChartEntry<Intent: NrqlWidgetIntent>: TimelineEntry {
    var date: Date = Date.now
    var comment: String?
    var resultContainer: NrdbResultContainer?
    let configuration: Intent
}

struct NrqlChartProvider<Intent: NrqlWidgetIntent>: AppIntentTimelineProvider {
    typealias Entry = NrqlChartEntry<Intent>

    let chartType: ChartType
    private let refreshInterval: TimeInterval = 60 * 5

    func placeholder(in context: Context) -> Entry {
        Entry(
            resultContainer: ChartSamples.randomSample(),
            configuration: Intent()
        )
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        Entry(
            resultContainer: ChartSamples.randomSample(for: chartType),
            configuration: configuration
        )
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        // Connection settings come from the app's Preferences (shared App Group)
        // rather than the intent, because Edit Widget is currently unusable.
        let queries = Queries()
        let resultContainer = try? await queries.getNrqlData(query: configuration.nrqlQuery, debug: true)

        let entry: Entry
        if let resultContainer {
            entry = Entry(resultContainer: resultContainer, configuration: configuration)
        } else {
            entry = Entry(comment: configuration.nrqlQuery, configuration: configuration)
        }
        return Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: refreshInterval)))
    }
}

/// Renders a chart for a widget entry. `configure` copies the intent's chart-specific
/// options onto the `ChartConfiguration`; `chart` builds the chart view.
struct NrqlChartWidgetView<Intent: NrqlWidgetIntent, Content: View>: View {
    let entry: NrqlChartEntry<Intent>
    var configure: (inout ChartConfiguration, Intent) -> Void = { _, _ in }
    @ViewBuilder let chart: (ChartConfiguration) -> Content

    private var configuration: ChartConfiguration? {
        guard let results = entry.resultContainer else { return nil }
        var config = ChartConfiguration(resultContainer: results)
        configure(&config, entry.configuration)
        return config
    }

    var body: some View {
        if let config = configuration {
            Text(entry.configuration.title)

            chart(config)
                .chartLegend(entry.configuration.showLegend ? .visible : .hidden)
        } else {
            Text("Error loading data")
        }
    }
}
