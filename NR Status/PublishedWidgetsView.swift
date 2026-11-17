import SwiftUI
import WidgetKit

enum WorkbookWidgetPublishing {
    static func updateAll(
        document: inout NRQL_EditorDocument, sourceName: String, sourceURL: URL? = nil, registry: WidgetRegistry
    ) throws {
        let published = try document.cells.filter { cell in
            guard let id = cell.widgetID else { return false }
            return try registry.widget(id: id) != nil
        }
        guard !published.isEmpty else { return }
        try publish(cellIDs: published.map(\.id), document: &document, sourceName: sourceName,
                    sourceURL: sourceURL, registry: registry)
    }

    static func unpublishAll(document: NRQL_EditorDocument, registry: WidgetRegistry) throws {
        for id in Set(document.cells.compactMap(\.widgetID)) {
            if let widget = try registry.widget(id: id) {
                try registry.remove(widget)
            }
        }
    }

    static func update(
        cellID: UUID, document: inout NRQL_EditorDocument, sourceName: String, sourceURL: URL? = nil,
        registry: WidgetRegistry
    ) throws {
        guard let id = document.cells.first(where: { $0.id == cellID })?.widgetID,
              try registry.widget(id: id) != nil else {
            throw NrqlConnection.ConfigurationError(message: "This cell is not published. Use Publish as Widget first.")
        }
        try publish(cellIDs: [cellID], document: &document, sourceName: sourceName,
                    sourceURL: sourceURL, registry: registry)
    }

    static func publish(
        cellIDs: [UUID], document: inout NRQL_EditorDocument, sourceName: String,
        sourceURL: URL? = nil, names: [UUID: String] = [:], registry: WidgetRegistry
    ) throws {
        let selected = document.cells.indices.filter { cellIDs.contains(document.cells[$0].id) }
        guard !selected.isEmpty, selected.count == cellIDs.count else {
            throw NrqlConnection.ConfigurationError(message: "The selected cells no longer exist.")
        }
        let sourceBookmark = try sourceURL?.bookmarkData(options: .withSecurityScope)
        var texts = document.cells.map(\.text)
        var configurations: [Int: String] = [:]
        var identities: [Int: UUID] = [:]
        for index in selected {
            let cell = document.cells[index]
            guard cell.canPublishWidget else {
                throw NrqlConnection.ConfigurationError(message: "Publish a chart or Markdown cell.")
            }
            let id = cell.widgetID ?? UUID()
            var source = NrqlCellSource(stored: cell.text)
            var configuration = source.configuration ?? ""
            if source.configuration == nil, cell.kind != .markdown {
                configuration = NrqlCellSource.updating("title", values: [cell.query.title], in: configuration)
            }
            configuration = NrqlCellSource.updating("widget-id", values: [id.uuidString], in: configuration)
            source.configuration = configuration
            texts[index] = source.storedText
            configurations[index] = configuration
            identities[index] = id
        }
        let snapshot = NRQL_EditorDocument(text: NrqlDocumentParser.join(texts))
        _ = try snapshot.connection.get()
        let widgets = try selected.map { index in
            let cell = document.cells[index]
            let id = identities[index]!
            let targets = snapshot.cells.filter { $0.widgetID == id }
            guard targets.count == 1, let target = targets.first else {
                throw NrqlConnection.ConfigurationError(message: "Duplicate widget-id. Remove it from the copied cell before publishing.")
            }
            _ = try WorkbookWidgetRunner.plan(target: target, in: snapshot.cells)
            let existing = try registry.widget(id: id)
            let name = (names[cell.id] ?? existing?.name ?? cell.query.title)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                throw NrqlConnection.ConfigurationError(message: "Give the widget a name.")
            }
            return PublishedWidget(
                id: id, revision: UUID(), name: name, sourceName: sourceName,
                cellTitle: cell.query.title, workbook: snapshot.text, publishedAt: Date(),
                sourceBookmark: sourceBookmark
            )
        }
        // Validate the entire batch before writing; keep identities for any successful saves.
        for (index, widget) in zip(selected, widgets) {
            try registry.save(widget)
            document.cells[index].configurationText = configurations[index]!
        }
    }

    static func unpublish(cellID: UUID, document: NRQL_EditorDocument, registry: WidgetRegistry) throws {
        guard let id = document.cells.first(where: { $0.id == cellID })?.widgetID,
              let widget = try registry.widget(id: id) else { return }
        // Retain the identity so republishing reconnects desktop widgets to the same cell.
        try registry.remove(widget)
    }
}

struct PublishWidgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var document: NRQL_EditorDocument
    let cellID: UUID?
    let sourceName: String
    var sourceURL: URL? = nil
    @State private var name = ""
    @State private var error: String?

    private var cells: [NrqlCell] {
        document.cells.filter { $0.canPublishWidget && (cellID == nil || $0.id == cellID) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(cellID == nil ? "Publish All Workbook Cells" : "Publish Workbook Cell").font(.headline)
            if cellID == nil {
                Text(sourceName).font(.subheadline)
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(cells) { cell in
                            Label(cell.query.title, systemImage: cell.kind == .markdown ? "text.alignleft" : "chart.xyaxis.line")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
                Text("Publishes \(cells.count) cells. Existing widgets keep their names and selections; new widgets use the cell titles.")
                    .foregroundStyle(.secondary)
            } else {
                TextField("Widget name", text: $name)
            }
            Text("Publishes a snapshot of this workbook. Its data refreshes even when NR Status is closed. Use Update Published Widget after changing the workbook.")
                .foregroundStyle(.secondary)
            Text("Save the workbook after publishing to keep the cell's widget identity. Only named results references are supported for widget dependencies.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if sourceURL == nil {
                Text("Save this workbook, then update the publication to let widget clicks open the source file. Until then, clicks offer to recover the published snapshot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button(cellID == nil ? "Publish / Update All" : "Publish") { publish() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(cells.isEmpty || (cellID != nil && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
        .padding()
        .frame(width: 440)
        .onAppear {
            guard cellID != nil, let cell = cells.first else { return }
            name = cell.query.title
            do {
                if let id = cell.widgetID, let existing = try WidgetRegistry.shared().widget(id: id) {
                    name = existing.name
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func publish() {
        defer { WidgetCenter.shared.reloadTimelines(ofKind: WidgetRegistry.widgetKind) }
        do {
            try WorkbookWidgetPublishing.publish(
                cellIDs: cells.map(\.id), document: &document, sourceName: sourceName,
                sourceURL: sourceURL, names: cellID.map { [$0: name] } ?? [:], registry: WidgetRegistry.shared()
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct PublishedWidgetsView: View {
    @State private var widgets: [PublishedWidget] = []
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading) {
            if widgets.isEmpty {
                ContentUnavailableView("No Published Widgets", systemImage: "square.grid.2x2",
                                       description: Text("Use a chart or Markdown cell's menu to Publish as Widget."))
            } else {
                List {
                    ForEach(PublishedWidgetGroup.grouping(widgets)) { group in
                        Section(group.sourceName) {
                            ForEach(group.widgets) { widget in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(widget.name).font(.headline)
                                        if widget.cellTitle != widget.name {
                                            Text(widget.cellTitle).foregroundStyle(.secondary)
                                        }
                                        Text("Published \(widget.publishedAt.formatted())").font(.caption)
                                    }
                                    Spacer()
                                    Button("Unpublish", role: .destructive) { remove(widget) }
                                }
                            }
                        }
                    }
                }
            }
            Text("Update or rename a widget by publishing its cell again. Removing a publication does not remove widgets already placed on the desktop.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            if let error { Text(error).foregroundStyle(.red).padding(.horizontal) }
            HStack {
                Spacer()
                Button("Refresh List") { load() }
            }
            .padding()
        }
        .onAppear { load() }
        .onReceive(NotificationCenter.default.publisher(for: WidgetRegistry.didChangeNotification)) { _ in load() }
    }

    private func load() {
        do {
            widgets = try WidgetRegistry.shared().widgets()
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func remove(_ widget: PublishedWidget) {
        do {
            try WidgetRegistry.shared().remove(widget)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetRegistry.widgetKind)
            load()
        } catch { self.error = error.localizedDescription }
    }
}
