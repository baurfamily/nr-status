import SwiftUI
import WidgetKit

struct PublishWidgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var document: NRQL_EditorDocument
    let cellID: UUID
    let sourceName: String
    @State private var name = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Publish Workbook Cell").font(.headline)
            TextField("Widget name", text: $name)
            Text("Publishes a snapshot of this workbook. Its data refreshes even when NR Status is closed. Use Update Published Widget after changing the workbook.")
                .foregroundStyle(.secondary)
            Text("Save the workbook after publishing to keep the cell's widget identity. Only named results references are supported for widget dependencies.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Publish") { publish() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 440)
        .onAppear {
            guard let cell = document.cells.first(where: { $0.id == cellID }) else { return }
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
        do {
            guard let index = document.cells.firstIndex(where: { $0.id == cellID }) else {
                throw NrqlConnection.ConfigurationError(message: "The selected cell no longer exists.")
            }
            let original = document.cells[index]
            let id = original.widgetID ?? UUID()
            var source = NrqlCellSource(stored: original.text)
            var configuration = source.configuration ?? ""
            if source.configuration == nil, original.kind != .markdown {
                configuration = NrqlCellSource.updating("title", values: [original.query.title], in: configuration)
            }
            configuration = NrqlCellSource.updating(
                "widget-id", values: [id.uuidString], in: configuration
            )
            source.configuration = configuration
            var texts = document.cells.map(\.text)
            texts[index] = source.storedText
            let snapshot = NRQL_EditorDocument(text: NrqlDocumentParser.join(texts))
            guard snapshot.cells.filter({ $0.widgetID == id }).count == 1 else {
                throw NrqlConnection.ConfigurationError(message: "Duplicate widget-id. Remove it from the copied cell before publishing.")
            }
            _ = try snapshot.connection.get()
            let target = snapshot.cells.first { $0.widgetID == id }!
            _ = try WorkbookWidgetRunner.plan(target: target, in: snapshot.cells)
            let widget = PublishedWidget(
                id: id, revision: UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                sourceName: sourceName, cellTitle: original.query.title,
                workbook: snapshot.text, publishedAt: Date()
            )
            try WidgetRegistry.shared().save(widget)
            document.cells[index].configurationText = configuration
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetRegistry.widgetKind)
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
                List(widgets) { widget in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(widget.name).font(.headline)
                            Text("\(widget.sourceName) / \(widget.cellTitle)").foregroundStyle(.secondary)
                            Text("Published \(widget.publishedAt.formatted())").font(.caption)
                        }
                        Spacer()
                        Button("Remove", role: .destructive) { remove(widget) }
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
