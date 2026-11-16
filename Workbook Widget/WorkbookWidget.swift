import SwiftUI
import WidgetKit
import os

struct WorkbookWidgetEntry: TimelineEntry {
    let date: Date
    var output: WorkbookWidgetOutput?
    var error: String?
    var isConfigured = false
    var isPreview = false
}

struct WorkbookWidgetProvider: AppIntentTimelineProvider {
    private let logger = Logger(subsystem: "net.baurhome.NR-Status.WorkbookWidget", category: "Timeline")

    func placeholder(in context: Context) -> WorkbookWidgetEntry {
        WorkbookWidgetEntry(date: Date(), isPreview: true)
    }

    func snapshot(for configuration: WorkbookWidgetIntent, in context: Context) async -> WorkbookWidgetEntry {
        if context.isPreview { return placeholder(in: context) }
        return await load(configuration)
    }

    func timeline(for configuration: WorkbookWidgetIntent, in context: Context) async -> Timeline<WorkbookWidgetEntry> {
        logger.info("Building timeline; configured: \(configuration.widget != nil, privacy: .public)")
        let entry = await load(configuration)
        logger.info("Timeline ready; output: \(entry.output != nil, privacy: .public), error: \(entry.error != nil, privacy: .public)")
        return Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: 5 * 60)))
    }

    private func load(_ configuration: WorkbookWidgetIntent) async -> WorkbookWidgetEntry {
        var entry = WorkbookWidgetEntry(date: Date(), isConfigured: configuration.widget != nil)
        guard let selection = configuration.widget, let id = UUID(uuidString: selection.id) else { return entry }
        do {
            let registry = try WidgetRegistry.shared()
            guard let widget = try registry.widget(id: id) else {
                throw NrqlConnection.ConfigurationError(message: "This widget was removed. Edit Widget to select another.")
            }
            entry.output = try? registry.cachedOutput(for: widget)
            let settings = URLSessionConfiguration.ephemeral
            settings.timeoutIntervalForRequest = NerdgraphClient.requestTimeoutInterval
            settings.timeoutIntervalForResource = NerdgraphClient.requestTimeoutInterval
            let session = URLSession(configuration: settings)
            defer { session.invalidateAndCancel() }
            let output = try await withThrowingTaskGroup(of: WorkbookWidgetOutput.self) { group in
                group.addTask { try await WorkbookWidgetRunner.run(widget, session: session) }
                group.addTask {
                    try await Task.sleep(for: .seconds(NerdgraphClient.requestTimeoutInterval))
                    throw NrqlConnection.ConfigurationError(message: "Widget refresh timed out.")
                }
                defer { group.cancelAll() }
                return try await group.next()!
            }
            // Publishing or removing a widget while it refreshes invalidates that run.
            guard try registry.widget(id: id)?.revision == widget.revision else {
                return WorkbookWidgetEntry(date: Date(), error: "Widget source changed. Refreshing shortly.", isConfigured: true)
            }
            entry.output = output
            do { try registry.cache(output, for: widget) }
            catch { entry.error = "Unable to save widget results: \(error.localizedDescription)" }
        } catch {
            entry.error = error.localizedDescription
        }
        return entry
    }
}

struct WorkbookWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WorkbookWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.isPreview {
                Text("Workbook Widget").font(.headline)
                if let sample = ChartSamples.randomSample(for: .billboard) {
                    ConfigurableChartView(resultsContainer: sample, format: .parseMetadata("chart: billboard"))
                        .widgetSized(for: family)
                }
            } else if let output = entry.output {
                if let markdown = output.markdown {
                    MarkdownView(text: markdown)
                } else if let results = output.resultContainer {
                    Text(output.title).font(.headline).lineLimit(1)
                    ConfigurableChartView(resultsContainer: results, format: output.configuration.map(ChartFormat.parseMetadata))
                        .widgetSized(for: family)
                }
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    if entry.error != nil { Image(systemName: "exclamationmark.triangle") }
                    Text(output.updatedAt, style: .time)
                    if entry.error != nil { Text("Refresh failed") }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .help(entry.error ?? "Last updated")
                .accessibilityLabel(entry.error ?? "Last updated")
            } else {
                Image(systemName: entry.isConfigured ? "exclamationmark.triangle" : "doc.richtext")
                Text(entry.isConfigured ? "Unable to load widget" : "Choose a published widget")
                    .font(.headline)
                Text(entry.error ?? "Publish a chart or Markdown cell in NR Status, then choose it in Edit Widget.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }
}

struct WorkbookWidget: Widget {
    let kind = WidgetRegistry.widgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WorkbookWidgetIntent.self, provider: WorkbookWidgetProvider()) { entry in
            WorkbookWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Workbook")
        .description("A chart or Markdown cell published from an NR Markdown workbook.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct WorkbookWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkbookWidget()
    }
}
