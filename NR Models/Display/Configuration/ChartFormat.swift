//
//  ChartFormat.swift
//  NR Status
//

import Foundation

/// Chart settings written in a doc-style comment at the top of a query:
///
///     /***
///     chart: line
///     attributes: smoothed, lines, points
///     ***/
///
/// With no `attributes` key, the chart keeps its defaults. When it is present,
/// every attribute that applies to the chart type is on if listed and off if not.
///
/// `name` lets later cells refer to this query's result as `results.<name>`, and
/// `chart: none` hides the chart, for queries that only feed other cells.
struct ChartFormat: Equatable, Hashable {
    var title: String?
    var name: String?
    var type: ChartType?
    var hidesChart = false
    var attributes: Set<String>?

    /// The attribute names each chart type understands; `apply` is the source of truth for what they do.
    static let attributeNames: [ChartType: [String]] = [
        .line: ["stacked", "smoothed", "lines", "points"],
        .pie: ["donut", "separated"],
        .bar: ["pivot"],
        .plot: ["color-facets", "x-log", "y-log"],
        .billboard: ["gauge"]
    ]
    private static let block = try! NSRegularExpression(
        pattern: #"/\*\*\*(.*?)\*\*\*/"#,
        options: [.dotMatchesLineSeparators]
    )

    /// The query text with any format block removed.
    static func strip(from text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return block.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    /// Reads the first format block in the text; nil if there isn't one.
    static func parse(from text: String) -> ChartFormat? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = block.firstMatch(in: text, range: range),
              let bodyRange = Range(match.range(at: 1), in: text)
        else { return nil }

        var format = ChartFormat()
        for line in text[bodyRange].split(whereSeparator: \.isNewline) {
            // only the first colon separates key from value, so titles can contain colons
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let rawValue = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            let value = rawValue.lowercased()

            switch key {
            case "title":
                format.title = rawValue.isEmpty ? nil : rawValue
            case "name":
                format.name = rawValue.isEmpty ? nil : rawValue
            case "chart":
                format.hidesChart = value == "none"
                format.type = ChartType(rawValue: value)
            case "attributes":
                let names = value.split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init)
                format.attributes = names.isEmpty ? nil : Set(names)
            default:
                // unknown keys are left alone for later features
                continue
            }
        }
        return format
    }

    func apply(to config: ChartConfiguration) {
        if let type, config.chartTypes.contains(type) {
            config.chartType = type
        }
        guard let attributes else { return }
        func on(_ name: String) -> Bool { attributes.contains(name) }

        switch config.chartType {
        case .line, nil:
            config.timeseries.isStacked = on("stacked")
            config.timeseries.isSmoothed = on("smoothed")
            config.timeseries.showLines = on("lines")
            config.timeseries.showDataPoints = on("points")
            // with neither, the chart would be invisible
            if !config.timeseries.showLines && !config.timeseries.showDataPoints {
                config.timeseries.showLines = true
            }
        case .pie:
            config.pie.isDonut = on("donut")
            config.pie.isSeparated = on("separated")
        case .bar:
            config.bar.pivotData = on("pivot")
        case .plot:
            config.plot.colorFacets = on("color-facets")
            config.plot.xLogScale = on("x-log")
            config.plot.yLogScale = on("y-log")
        case .billboard:
            config.billboard.showGauge = on("gauge")
        case .table:
            break
        }
    }
}
