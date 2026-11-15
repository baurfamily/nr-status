//
//  TableChart.swift
//  NR Status
//
//  Created by Eric Baur on 10/26/24.
//

import SwiftUI

struct TableChart : View {
    var config: ChartConfiguration
    
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
