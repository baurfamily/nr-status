import Foundation

struct PublishedWidget: Codable, Identifiable, Sendable {
    let id: UUID
    let revision: UUID
    var name: String
    let sourceName: String
    let cellTitle: String
    let workbook: String
    let publishedAt: Date
}

struct WorkbookWidgetOutput: Codable, Sendable {
    let title: String
    let updatedAt: Date
    var markdown: String?
    var chart: JSONValue?
    var configuration: String?

    var resultContainer: NrdbResultContainer? {
        guard let chart else { return nil }
        return try? LuaResultBridge.container(from: chart.luaValue)
    }
}

struct WidgetRegistry {
    static let widgetKind = "net.baurhome.nrstatus.workbook"
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    static func shared() throws -> WidgetRegistry {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: NerdgraphConfig.appGroup
        ) else {
            throw NrqlConnection.ConfigurationError(message: "The shared widget container is unavailable.")
        }
        return WidgetRegistry(directory: container.appendingPathComponent("Published Widgets", isDirectory: true))
    }

    func widgets() throws -> [PublishedWidget] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasSuffix(".nrwidget.json") }
            .map { try JSONDecoder().decode(PublishedWidget.self, from: Data(contentsOf: $0)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func widget(id: UUID) throws -> PublishedWidget? {
        let url = publicationURL(id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(PublishedWidget.self, from: Data(contentsOf: url))
    }

    func save(_ widget: PublishedWidget) throws {
        guard !widget.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NrqlConnection.ConfigurationError(message: "Give the widget a name.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let previous = try self.widget(id: widget.id)
        try JSONEncoder().encode(widget).write(to: publicationURL(widget.id), options: .atomic)
        if let previous, previous.revision != widget.revision {
            try? removeCache(for: previous)
        }
    }

    func remove(_ widget: PublishedWidget) throws {
        try FileManager.default.removeItem(at: publicationURL(widget.id))
        try? removeCache(for: widget)
    }

    func cachedOutput(for widget: PublishedWidget) throws -> WorkbookWidgetOutput? {
        let url = cacheURL(widget)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(WorkbookWidgetOutput.self, from: Data(contentsOf: url))
    }

    func cache(_ output: WorkbookWidgetOutput, for widget: PublishedWidget) throws {
        // A refresh of an older publication must not overwrite the newly published version.
        guard try self.widget(id: widget.id)?.revision == widget.revision else { return }
        try JSONEncoder().encode(output).write(to: cacheURL(widget), options: .atomic)
    }

    private func publicationURL(_ id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString + ".nrwidget.json")
    }

    private func cacheURL(_ widget: PublishedWidget) -> URL {
        directory.appendingPathComponent(widget.id.uuidString + "." + widget.revision.uuidString + ".result.json")
    }

    private func removeCache(for widget: PublishedWidget) throws {
        let url = cacheURL(widget)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
