//
//  ChartFormat.swift
//  NR Status
//

import Foundation

/// Chart settings written in a doc-style comment at the top of a query:
///
///     /***
///     type: line
///     attributes: smoothed, lines, points
///     ***/
///
/// With no `attributes` key, the chart keeps its defaults. When it is present,
/// every attribute that applies to the chart type is on if listed and off if not.
struct ChartFormat: Equatable {
    var type: ChartType?
    var attributes: Set<String>?

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
            let parts = line.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces).lowercased()
            }
            guard parts.count == 2 else { continue }

            switch parts[0] {
            case "type":
                format.type = ChartType(rawValue: parts[1])
            case "attributes":
                let names = parts[1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
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
