//
//  NrqlExport.swift
//  NR Status
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Writes a document out as plain NRQL, HTML (queries with the charts of any loaded results) or PDF.
/// Queries that haven't been run are exported as text only.
@MainActor
enum NrqlExport {
    enum Format: CaseIterable {
        case nrql, html, pdf

        var title: String {
            switch self {
            case .nrql: "NRQL Text…"
            case .html: "HTML…"
            case .pdf: "PDF…"
            }
        }

        var contentType: UTType {
            switch self {
            case .nrql: .plainText
            case .html: .html
            case .pdf: .pdf
            }
        }

        var fileExtension: String {
            switch self {
            case .nrql: "nrql"
            case .html: "html"
            case .pdf: "pdf"
            }
        }
    }

    static func data(for format: Format, document: NRQL_EditorDocument) -> Data? {
        switch format {
        case .nrql: Data(document.text.utf8)
        case .html: Data(html(for: document).utf8)
        case .pdf: pdf(for: document)
        }
    }

    /// Asks where to save, then writes the export.
    static func save(_ format: Format, document: NRQL_EditorDocument, suggestedName: String = "Queries") {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "\(suggestedName).\(format.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            guard let data = data(for: format, document: document) else { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    // MARK: - Charts

    private static func chartView(for cell: NrqlCell, width: CGFloat) -> some View {
        Group {
            if let container = cell.query.resultContainer {
                ConfigurableChartView(
                    resultsContainer: container, format: cell.query.format, configurationShowing: .constant(false)
                )
            }
        }
        .frame(width: width, height: 300)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private static func chartPNG(for cell: NrqlCell) -> Data? {
        guard cell.query.resultContainer != nil else { return nil }
        let renderer = ImageRenderer(content: chartView(for: cell, width: 700))
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    // MARK: - HTML

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func html(for document: NRQL_EditorDocument) -> String {
        let sections = document.cells.map { cell -> String in
            var section = "<section>\n<h2>\(escape(cell.query.title))</h2>\n<pre>\(escape(cell.text))</pre>\n"
            if let png = chartPNG(for: cell) {
                section += "<img alt=\"Chart\" src=\"data:image/png;base64,\(png.base64EncodedString())\">\n"
            } else if let message = cell.query.errorMessage {
                section += "<p class=\"error\">\(escape(message))</p>\n"
            }
            return section + "</section>"
        }
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>NRQL Queries</title>
        <style>
        body { font-family: -apple-system, sans-serif; max-width: 800px; margin: 2em auto; color: #222; }
        pre { background: #f4f4f6; padding: 0.8em; border-radius: 6px; white-space: pre-wrap; }
        img { max-width: 100%; }
        .error { color: #b00020; }
        section { margin-bottom: 2.5em; }
        </style>
        </head>
        <body>
        \(sections.joined(separator: "\n"))
        </body>
        </html>
        """
    }

    // MARK: - PDF

    private static func pageView(for cell: NrqlCell) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(cell.query.title).font(.title2.bold())
            Text(cell.text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.12))
            if cell.query.resultContainer != nil {
                chartView(for: cell, width: 532)
            } else if let message = cell.query.errorMessage {
                Text(message).foregroundStyle(.red)
            }
            Spacer(minLength: 0)
        }
        .padding(40)
        .frame(width: 612, height: 792, alignment: .topLeading)
        .background(Color.white)
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
    }

    /// One US Letter page per query.
    static func pdf(for document: NRQL_EditorDocument) -> Data? {
        let output = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil)
        else { return nil }

        for cell in document.cells {
            let renderer = ImageRenderer(content: pageView(for: cell))
            renderer.render { _, draw in
                context.beginPDFPage(nil)
                draw(context)
                context.endPDFPage()
            }
        }
        context.closePDF()
        return output as Data
    }
}
