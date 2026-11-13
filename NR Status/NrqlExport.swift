//
//  NrqlExport.swift
//  NR Status
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Writes a document out as HTML (queries with the charts of any loaded results) or PDF.
/// Queries that haven't been run are exported as text only.
@MainActor
enum NrqlExport {
    enum Format: CaseIterable {
        case html, pdf

        var title: String {
            switch self {
            case .html: "HTML…"
            case .pdf: "PDF…"
            }
        }

        var contentType: UTType {
            switch self {
            case .html: .html
            case .pdf: .pdf
            }
        }

        var fileExtension: String {
            switch self {
            case .html: "html"
            case .pdf: "pdf"
            }
        }
    }

    static func data(for format: Format, document: NRQL_EditorDocument) -> Data? {
        switch format {
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

    // MARK: - Tables

    /// Tables can't be drawn by `ImageRenderer` (they come out as a placeholder), so they're exported as plain data.
    struct TableData {
        var headers: [String]
        var rows: [[String]]
    }

    static func tableData(for cell: NrqlCell) -> TableData? {
        guard cell.query.format?.hidesChart != true, let container = cell.query.resultContainer else { return nil }
        let config = ChartConfiguration(resultContainer: container)
        cell.query.format?.apply(to: config)
        guard config.chartType == .table else { return nil }

        let showsTime = container.isTimeseries || container.isEvents
        let fields = container.fieldNames
        let headers = (showsTime ? ["Timestamp"] : []) + fields
        let rows = container.data.map { datum -> [String] in
            let values = fields.map { field -> String in
                if let number = datum.numberFields[field] { return String(number) }
                return datum.stringFields[field] ?? ""
            }
            let time = datum.date.map { $0.formatted(date: .abbreviated, time: .standard) } ?? ""
            return (showsTime ? [time] : []) + values
        }
        return TableData(headers: headers, rows: rows)
    }

    private static let htmlRowLimit = 100

    private static func htmlTable(_ table: TableData) -> String {
        let head = table.headers.map { "<th>\(escape($0))</th>" }.joined()
        let body = table.rows.prefix(htmlRowLimit).map { row in
            "<tr>" + row.map { "<td>\(escape($0))</td>" }.joined() + "</tr>"
        }.joined(separator: "\n")
        var html = "<table>\n<thead><tr>\(head)</tr></thead>\n<tbody>\n\(body)\n</tbody>\n</table>\n"
        if table.rows.count > htmlRowLimit {
            html += "<p><em>Showing \(htmlRowLimit) of \(table.rows.count) rows; the table is too large to include in full.</em></p>\n"
        }
        return html
    }

    private static let pdfRowHeight: CGFloat = 18

    private static func pdfTableNote(_ table: TableData, shownRows: Int, shownColumns: Int) -> String {
        var parts: [String] = []
        if table.rows.count > shownRows { parts.append("\(shownRows) of \(table.rows.count) rows") }
        if table.headers.count > shownColumns { parts.append("\(shownColumns) of \(table.headers.count) columns") }
        return "Showing \(parts.joined(separator: " and ")); the table is too large to print in full."
    }

    private static func pdfTable(_ table: TableData, maxRows: Int) -> some View {
        let shown = Array(table.rows.prefix(maxRows))
        // Columns narrower than this can't show anything useful.
        let columnCount = min(table.headers.count, max(Int(532 / 70), 1))
        let headers = Array(table.headers.prefix(columnCount))
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    Text(header).bold().lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: pdfRowHeight)
            Divider()
            ForEach(Array(shown.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(Array(row.prefix(columnCount).enumerated()), id: \.offset) { _, value in
                        Text(value).lineLimit(1).truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(height: pdfRowHeight)
            }
            if table.rows.count > shown.count || table.headers.count > columnCount {
                Text(pdfTableNote(table, shownRows: shown.count, shownColumns: columnCount))
                    .italic().foregroundStyle(.secondary).padding(.top, 6)
            }
        }
        .font(.system(size: 10))
    }

    // MARK: - Charts

    private static func chartView(for cell: NrqlCell, width: CGFloat) -> some View {
        Group {
            if let container = cell.query.resultContainer {
                ConfigurableChartView(
                    resultsContainer: container, format: cell.query.format, configurationShowing: .constant(false)
                )
                .withoutConfiguration()
            }
        }
        .frame(width: width, height: 300)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private static func chartPNG(for cell: NrqlCell) -> Data? {
        guard cell.query.format?.hidesChart != true, cell.query.resultContainer != nil else { return nil }
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
            if cell.kind == .markdown {
                return "<section>\n\(MarkdownParser.html(cell.text))\n</section>"
            }
            var section = "<section>\n<h2>\(escape(cell.query.title))</h2>\n<pre>\(escape(queryText(for: cell)))</pre>\n"
            if let table = tableData(for: cell) {
                section += htmlTable(table)
            } else if let png = chartPNG(for: cell) {
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
        table { border-collapse: collapse; font-size: 0.85em; }
        th, td { border-bottom: 1px solid #ddd; padding: 3px 10px; text-align: left; }
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

    private static let pageSize = CGSize(width: 612, height: 792)
    private static let pageMargin: CGFloat = 40
    private static let blockSpacing: CGFloat = 16

    /// A piece of the document that is placed on a page as a unit.
    private struct PDFBlock {
        var view: AnyView
        var keepWithNext = false
    }

    private static func pdfBlocks(for cell: NrqlCell) -> [PDFBlock] {
        if cell.kind == .markdown {
            return MarkdownParser.blocks(cell.text).map { block in
                var isHeading = false
                if case .heading = block { isHeading = true }
                return PDFBlock(view: AnyView(MarkdownView(blocks: [block])), keepWithNext: isHeading)
            }
        }
        return [PDFBlock(view: AnyView(codeBlockView(for: cell)))]
    }

    /// The query as the PDF shows it; the chart settings are already visible in the chart.
    private static func queryText(for cell: NrqlCell) -> String {
        ChartFormat.strip(from: cell.editorText, lua: cell.kind == .lua)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func codeBlockView(for cell: NrqlCell) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(cell.query.title).font(.title2.bold())
            Text(queryText(for: cell))
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.12))
            if let table = tableData(for: cell) {
                // what's left of the page after the title and the query text
                let queryLines = queryText(for: cell).split(separator: "\n", omittingEmptySubsequences: false).count
                let room = 560 - CGFloat(queryLines) * 16
                pdfTable(table, maxRows: max(Int(room / pdfRowHeight) - 3, 3))
            } else if cell.query.resultContainer != nil, cell.query.format?.hidesChart != true {
                chartView(for: cell, width: 532)
            } else if let message = cell.query.errorMessage {
                Text(message).foregroundStyle(.red)
            }
        }
    }

    private static func pdfRenderer(_ block: PDFBlock) -> ImageRenderer<some View> {
        ImageRenderer(
            content: block.view
                .frame(width: pageSize.width - pageMargin * 2, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.white)
                .foregroundStyle(Color.black)
                .environment(\.colorScheme, .light)
        )
    }

    private static func pdfHeight(of block: PDFBlock) -> CGFloat {
        var height: CGFloat = 0
        pdfRenderer(block).render { size, _ in height = size.height }
        return height
    }

    /// Letter pages; blocks flow down the page and only start a new one when the next block doesn't fit.
    /// A heading stays with the block after it, and a query stays with its chart.
    static func pdf(for document: NRQL_EditorDocument) -> Data? {
        let output = NSMutableData()
        var box = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil)
        else { return nil }

        let blocks = document.cells.flatMap(pdfBlocks(for:))
        let heights = blocks.map(pdfHeight(of:))
        let contentHeight = pageSize.height - pageMargin * 2

        var y: CGFloat = 0
        var pageOpen = false
        for (index, block) in blocks.enumerated() {
            var needed = heights[index]
            if block.keepWithNext, index + 1 < blocks.count { needed += blockSpacing + heights[index + 1] }
            if !pageOpen || (y > 0 && y + needed > contentHeight) {
                if pageOpen { context.endPDFPage() }
                context.beginPDFPage(nil)
                context.setFillColor(CGColor(gray: 1, alpha: 1))
                context.fill(box)
                pageOpen = true
                y = 0
            }
            context.saveGState()
            context.translateBy(x: pageMargin, y: pageSize.height - pageMargin - y - heights[index])
            pdfRenderer(block).render { _, draw in draw(context) }
            context.restoreGState()
            y += heights[index] + blockSpacing
        }
        if pageOpen { context.endPDFPage() }
        context.closePDF()
        return output as Data
    }
}
