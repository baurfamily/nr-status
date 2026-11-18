//
//  ChartFormat.swift
//  NR Status
//

import Foundation

/// Chart settings written as plain key/value lines in a cell_config fence:
///
///     chart: line
///     height: 20
///     attributes: smoothed, lines, points
///
/// With no `attributes` key, the chart keeps its defaults. When it is present,
/// every attribute that applies to the chart type is on if listed and off if not.
///
/// `var` lets later cells refer to this query's result as `results.<name>`, and
/// `chart: none` hides the chart, for queries that only feed other cells.
/// `chart: json` displays the result data as JSON instead of a chart.
/// `query: hide` starts the code collapsed and omits it from exports, independently
/// of the live expand/collapse state.
struct ChartFormat: Equatable, Hashable {
    var title: String?
    var name: String?
    var type: ChartType?
    var heightInLines: Int?
    var hidesChart = false
    var hidesQuery = false
    var showsJSON = false
    var showsBindings = false
    var showsConsole = false
    var attributes: Set<String>?

    /// The attribute names each chart type understands; `apply` is the source of truth for what they do.
    static let attributeNames: [ChartType: [String]] = [
        .line: ["stacked", "smoothed", "lines", "points"],
        .pie: ["donut", "separated"],
        .bar: ["pivot"],
        .plot: ["color-facets", "x-log", "y-log"],
        .billboard: ["gauge"]
    ]
    private static let attributePattern = try! NSRegularExpression(pattern: #"[\w-]+\([^)]*\)|[\w-]+"#)

    static func parseAttributes(_ text: String) -> Set<String> {
        Set(attributePattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            guard let range = Range($0.range, in: text) else { return nil }
            let token = String(text[range])
            return token.contains("(") ? token : token.lowercased()
        })
    }

    func parameter(_ name: String) -> String? {
        attributes?.sorted().first { $0.hasPrefix(name + "(") && $0.hasSuffix(")") }
            .map { String($0.dropFirst(name.count + 1).dropLast()) }
    }

    static func parseMetadata(_ body: String) -> ChartFormat {
        var format = ChartFormat()
        guard let yaml = try? ConfigurationYAML(body) else { return format }
        for field in yaml.fields {
            let key = field.key
            let rawValue = (try? yaml.value(key)) ?? ""
            let value = rawValue.lowercased()

            switch key {
            case "title":
                format.title = rawValue.isEmpty ? nil : rawValue
            case "var":
                format.name = (try? yaml.scalarValue("var")).flatMap { $0.isEmpty ? nil : $0 }
            case "chart":
                format.hidesChart = value == "none"
                format.showsJSON = value == "json"
                format.showsBindings = value == "bindings"
                format.showsConsole = value == "console"
                format.type = ChartType(rawValue: value)
            case "query":
                format.hidesQuery = value == "hide"
            case "height":
                format.heightInLines = Int(value).flatMap { $0 > 0 ? $0 : nil }
            case "attributes":
                format.attributes = parseAttributes(rawValue)
            default:
                // unknown keys are left alone for later features
                continue
            }
        }
        return format
    }

    func apply(to config: ChartConfiguration) {
        config.heightInLines = heightInLines
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
            if let field = parameter("x") { config.plot.xField = field }
            if let field = parameter("y") { config.plot.yField = field }
            if let field = parameter("color") { config.plot.colorField = field.isEmpty ? nil : field }
            if let field = parameter("size") { config.plot.sizeField = field.isEmpty ? nil : field }
        case .billboard:
            config.billboard.showGauge = on("gauge")
            if let maximum = parameter("max").flatMap(Double.init), maximum.isFinite, maximum > 0 {
                config.billboard.gaugeMax = maximum
            }
            if let style = parameter("style").flatMap(BillboardConfiguration.GaugeStyle.init(rawValue:)) {
                config.billboard.gaugeStyle = style
            }
        case .table:
            break
        }
    }
}
