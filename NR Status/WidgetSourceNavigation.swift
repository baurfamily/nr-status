import SwiftUI

@MainActor @Observable
final class WidgetSourceNavigation {
    static let shared = WidgetSourceNavigation()

    struct RevealRequest: Identifiable {
        let id = UUID()
        let widget: PublishedWidget
        let fileURL: URL
    }

    private(set) var revealRequest: RevealRequest?
    private var accessedURLs: Set<URL> = []

    func open(_ url: URL) async {
        guard let id = WorkbookWidgetLink.widgetID(from: url) else { return }
        NSApp.activate()
        do {
            guard let widget = try WidgetRegistry.shared().widget(id: id) else {
                showError("Widget chart source file not found",
                          message: "This widget is no longer published, so its saved workbook snapshot is also unavailable.")
                return
            }
            do {
                if let sourceURL = try widget.sourceURL() {
                    try await open(widget, at: sourceURL)
                    return
                }
            } catch {
                await recover(widget, detail: "The original workbook could not be opened: \(error.localizedDescription)")
                return
            }
            await recover(widget, detail: "No source file was recorded for this publication. Save the workbook and update the publication to enable click-through.")
        } catch {
            showError("Widget chart source file not found", message: error.localizedDescription)
        }
    }

    func recover(_ widget: PublishedWidget, title: String = "Widget chart source file not found", detail: String) async {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = """
            \(detail)

            Recover "\(widget.sourceName)" from the snapshot published \(widget.publishedAt.formatted())? \
            It includes the chart's query, configuration, and workbook dependencies, but not changes made after publishing.
            """
        alert.addButton(withTitle: "Recover Workbook...")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let panel = NSSavePanel()
        panel.title = "Recover Published Workbook"
        panel.message = "Save a recovered copy of the published snapshot. The original workbook is not changed."
        panel.allowedContentTypes = [.nrMarkdown]
        panel.nameFieldStringValue = "Recovered " + URL(fileURLWithPath: widget.sourceName).lastPathComponent
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if let sourceURL = try? widget.sourceURL(),
               sourceURL.resolvingSymlinksInPath() == url.resolvingSymlinksInPath() {
                throw NrqlConnection.ConfigurationError(message: "Choose a different filename for the recovered copy to preserve the original workbook.")
            }
            try widget.workbook.write(to: url, atomically: true, encoding: .utf8)
            try await open(widget, at: url)
        } catch {
            showError("Unable to recover widget workbook", message: error.localizedDescription)
        }
    }

    func stopAccessingSources() {
        for url in accessedURLs { url.stopAccessingSecurityScopedResource() }
        accessedURLs.removeAll()
    }

    private func open(_ widget: PublishedWidget, at url: URL) async throws {
        let startedAccess = !accessedURLs.contains(url) && url.startAccessingSecurityScopedResource()
        // Keep bookmark access alive for subsequent saves, and reuse it for repeated clicks.
        if startedAccess { accessedURLs.insert(url) }
        let request = RevealRequest(widget: widget, fileURL: url.standardizedFileURL)
        revealRequest = request
        do {
            let (document, _) = try await NSDocumentController.shared.openDocument(withContentsOf: url, display: true)
            document.showWindows()
            document.windowControllers.first?.window?.makeKeyAndOrderFront(nil)
        } catch {
            if startedAccess {
                accessedURLs.remove(url)
                url.stopAccessingSecurityScopedResource()
            }
            if revealRequest?.id == request.id { revealRequest = nil }
            throw error
        }
    }

    private func showError(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
