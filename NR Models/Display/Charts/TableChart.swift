//
//  TableChart.swift
//  NR Status
//
//  Created by Eric Baur on 10/26/24.
//

import SwiftUI

struct TableChart : View {
    var config: ChartConfiguration
    var isWidget = false
    
    var resultContainer: NrdbResultContainer {
        config.resultContainer
    }
    
    func value(for field: String, in datum: NrdbResults.Datum?) -> String {
        guard let datum else { return "" }
        var result: String
        
        if datum.numberFields.keys.contains(field) {
            result = String(datum.numberFields[field] ?? 0)
        } else {
            result = String(datum.stringFields[field] ?? "")
        }
        
        return result
    }
    
    // row ids are positional: event timestamps (and other derived ids) can repeat,
    // and duplicate ids crash Table
    struct Row : Identifiable {
        let id: Int
        let current: NrdbResults.Datum?
        let previous: NrdbResults.Datum?

        var datum: NrdbResults.Datum { (current ?? previous)! }
    }

    private struct ComparisonKey: Hashable {
        let date: Date?
        let duration: TimeInterval?
        let facets: [String]
    }

    private struct Pair {
        var current: [NrdbResults.Datum] = []
        var previous: [NrdbResults.Datum] = []
    }

    var rows: [Row] {
        guard resultContainer.isComparable else {
            return resultContainer.data.enumerated().map {
                Row(id: $0.offset, current: $0.element, previous: nil)
            }
        }

        var keys: [ComparisonKey] = []
        var pairs: [ComparisonKey: Pair] = [:]
        for datum in resultContainer.data {
            let key = ComparisonKey(
                date: resultContainer.comparisonDate(for: datum),
                duration: datum.beginTime.flatMap { begin in
                    datum.endTime?.timeIntervalSince(begin)
                },
                facets: datum.facets ?? [datum.facet].compactMap { $0 }
            )
            if pairs[key] == nil {
                keys.append(key)
                pairs[key] = Pair()
            }
            if datum.comparison == .current {
                pairs[key]!.current.append(datum)
            } else {
                pairs[key]!.previous.append(datum)
            }
        }

        // Pair duplicate keys by occurrence without discarding any source rows.
        var rows: [Row] = []
        for key in keys {
            let pair = pairs[key]!
            for index in 0..<max(pair.current.count, pair.previous.count) {
                rows.append(Row(
                    id: rows.count,
                    current: index < pair.current.count ? pair.current[index] : nil,
                    previous: index < pair.previous.count ? pair.previous[index] : nil
                ))
            }
        }
        return rows
    }

    private struct Column: Hashable {
        let field: String
        let comparison: NrdbResults.Datum.Comparison?

        var title: String {
            guard let comparison else { return field }
            return "\(field) (\(comparison == .current ? "Current" : "Previous"))"
        }
    }

    private var columns: [Column] {
        resultContainer.fieldNames.flatMap { field in
            if resultContainer.isComparable {
                return [
                    Column(field: field, comparison: .current),
                    Column(field: field, comparison: .previous)
                ]
            }
            return [Column(field: field, comparison: nil)]
        }
    }
    
    var body: some View {
        if isWidget {
            widgetTable
        } else {
            nativeTable
        }
    }

    private var widgetHeadings: [String] {
        (resultContainer.isTimeseries || resultContainer.isEvents ? ["Timestamp"] : [])
            + (resultContainer.isFaceted || resultContainer.isMultiFaceted ? ["Facet"] : [])
            + columns.map(\.title)
    }

    private func widgetValues(for row: Row) -> [String] {
        var values: [String] = []
        if resultContainer.isTimeseries || resultContainer.isEvents {
            values.append(resultContainer.comparisonDate(for: row.datum)?.formatted(date: .omitted, time: .shortened) ?? "")
        }
        if resultContainer.isFaceted || resultContainer.isMultiFaceted {
            values.append(row.datum.facet ?? row.datum.facets?.joined(separator: ", ") ?? "")
        }
        return values + columns.map { column in
            value(for: column.field, in: column.comparison == .previous ? row.previous : row.current)
        }
    }

    private var widgetTable: some View {
        GeometryReader { geometry in
            let headings = widgetHeadings
            let rowHeight: CGFloat = 22
            let capacity = max(0, Int((geometry.size.height - rowHeight) / rowHeight))
            let visibleCount = rows.count > capacity ? max(0, capacity - 1) : capacity
            let width = max(1, (geometry.size.width - CGFloat(max(0, headings.count - 1)) * 6) / CGFloat(max(1, headings.count)))
            VStack(alignment: .leading, spacing: 0) {
                Grid(horizontalSpacing: 6, verticalSpacing: 0) {
                    GridRow {
                        ForEach(headings.indices, id: \.self) { index in
                            Text(headings[index]).fontWeight(.semibold)
                                .frame(width: width, height: rowHeight, alignment: .leading)
                        }
                    }
                    .foregroundStyle(.secondary)
                    ForEach(rows.prefix(visibleCount)) { row in
                        let values = widgetValues(for: row)
                        GridRow {
                            ForEach(values.indices, id: \.self) { index in
                                Text(values[index])
                                    .monospacedDigit()
                                    .frame(width: width, height: rowHeight, alignment: .leading)
                            }
                        }
                        .background(row.id.isMultiple(of: 2) ? Color.primary.opacity(0.04) : .clear)
                    }
                }
                if rows.count > visibleCount {
                    Text("\(rows.count - visibleCount) more rows")
                        .foregroundStyle(.secondary)
                        .frame(height: rowHeight)
                }
            }
            .font(.caption2)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .clipped()
        }
    }

    private var nativeTable: some View {
        // the column set varies with the query; rebuild the table when it changes
        Table(rows) {
            if resultContainer.isTimeseries || resultContainer.isEvents {
                TableColumn("Timestamp") { (row: Row) in
                    if let date = resultContainer.comparisonDate(for: row.datum) {
                        Text(date, style: .relative)
                    }
                }
            }
            if resultContainer.isComparable && (resultContainer.isFaceted || resultContainer.isMultiFaceted) {
                TableColumn("Facet") { (row: Row) in
                    Text(row.datum.facet ?? row.datum.facets?.joined(separator: ", ") ?? "")
                }
            }
            TableColumnForEach(columns, id: \.self) { column in
                TableColumn(column.title) { (row: Row) in
                    let datum = column.comparison == .previous ? row.previous : row.current
                    Text(value(for: column.field, in: datum))
                        .help(datum?.date?.formatted() ?? "")
                }
            }
        }
        .id(resultContainer.fieldNames)
        .id(resultContainer.isComparable)
        .id(resultContainer.isTimeseries || resultContainer.isEvents)
        .id(resultContainer.isFaceted || resultContainer.isMultiFaceted)
    }
}

#Preview("Event data") {
    if let single = ChartSamples.sampleData(facet: .none, timeseries: false, comparable: false, size: .large) {
        Text("data \(single.results.data.count)")
        TableChart(config: .init(resultContainer: single))
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .none, timeseries: false, comparable: false, size: .large))
    }
}

#Preview("Single Facet") {
    if let single = ChartSamples.sampleData(facet: .single, timeseries: false, comparable: false, size: .small) {
        Text("data \(single.results.data.count)")
        TableChart(config: .init(resultContainer: single))
    } else {
        Text("No sample data")
        Text(ChartSamples.sampleFilename(facet: .single, timeseries: false, comparable: false, size: .small))
    }
}
