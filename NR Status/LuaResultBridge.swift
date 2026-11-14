//
//  LuaResultBridge.swift
//  NR Status
//

import Foundation
import LuaSwift

/// Converts query results to and from Lua tables.
///
/// A result is a table `{ nrql = "...", columns = {...}, rows = { {...}, ... }, facets = {...} }`.
/// Rows use the same keys as the NerdGraph JSON (`beginTimeSeconds`, `endTimeSeconds`,
/// `timestamp`, `facet`, `comparison`, plus one key per selected field), so a table
/// built by a script goes through the same decoder, and charts, as a real query.
enum LuaResultBridge {
    enum BridgeError: LocalizedError {
        case notAResult
        case invalidRow(Int)

        var errorDescription: String? {
            switch self {
            case .notAResult: "A result must be a table with a `rows` list, or a list of row tables."
            case .invalidRow(let index): "Row \(index) is not a table of fields."
            }
        }
    }

    // MARK: - Container -> Lua

    static func luaValue(from container: NrdbResultContainer) -> LuaValue {
        var table: [String: LuaValue] = [
            "nrql": .string(container.nrql),
            "columns": .array(container.fieldNames.map { .string($0) }),
            "rows": rowsValue(from: container),
        ]
        if let facets = container.metadata.facets {
            table["facets"] = .array(facets.map { .string($0) })
        }
        return .table(table)
    }

    static func rowsValue(from container: NrdbResultContainer) -> LuaValue {
        .array(container.data.map(row))
    }

    private static func row(_ datum: NrdbResults.Datum) -> LuaValue {
        var fields: [String: LuaValue] = [:]
        if let begin = datum.beginTime { fields["beginTimeSeconds"] = .number(begin.timeIntervalSince1970) }
        if let end = datum.endTime { fields["endTimeSeconds"] = .number(end.timeIntervalSince1970) }
        if let timestamp = datum.timestamp { fields["timestamp"] = .number(timestamp.timeIntervalSince1970) }
        if datum.isComparable { fields["comparison"] = .string(datum.comparison.rawValue) }
        if let facet = datum.facet {
            fields["facet"] = .string(facet)
        } else if let facets = datum.facets {
            fields["facet"] = .array(facets.map { .string($0) })
        }
        for (name, value) in datum.numberFields { fields[name] = .number(value) }
        for (name, value) in datum.stringFields { fields[name] = .string(value) }
        for (name, values) in datum.numericArrayFields { fields[name] = .array(values.map { .number($0) }) }
        for (name, values) in datum.stringArrayFields { fields[name] = .array(values.map { .string($0) }) }
        for (name, values) in datum.numericDictFields { fields[name] = .table(values.mapValues { .number($0) }) }
        return .table(fields)
    }

    // MARK: - Lua -> container

    /// Accepts a table with a `rows` list, or a bare list of row tables.
    static func container(from value: LuaValue) throws -> NrdbResultContainer {
        var rows: [LuaValue]
        var nrql = ""
        var facets: [String]?

        switch value {
        case .array(let items):
            rows = items
        case .table(let table):
            guard let items = asList(table["rows"]) else { throw BridgeError.notAResult }
            rows = items
            nrql = table["nrql"]?.stringValue ?? ""
            facets = asList(table["facets"])?.compactMap(\.stringValue)
        default:
            throw BridgeError.notAResult
        }

        let jsonRows = try rows.enumerated().map { index, row -> [String: Any] in
            guard case .table(let fields) = row else {
                // an empty Lua table arrives as an empty array
                if case .array(let items) = row, items.isEmpty { return [:] }
                throw BridgeError.invalidRow(index + 1)
            }
            return fields.reduce(into: [:]) { json, entry in
                json[entry.key] = jsonObject(entry.value, key: entry.key)
            }
        }

        var metadata: [String: Any] = ["timeWindow": NSNull()]
        metadata["facets"] = facets ?? NSNull()
        let json: [String: Any] = ["nrql": nrql, "results": jsonRows, "metadata": metadata]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(NrdbResultContainer.self, from: data)
    }

    private static func asList(_ value: LuaValue?) -> [LuaValue]? {
        switch value {
        case .array(let items): items
        case .table(let table) where table.isEmpty: []
        default: nil
        }
    }

    private static func jsonObject(_ value: LuaValue, key: String? = nil) -> Any {
        switch value {
        case .string(let string): string
        case .number(let number):
            // a numeric facet is still a facet name
            key == "facet" ? (number == number.rounded() ? String(Int(number)) : String(number)) : number
        case .bool(let bool): bool
        case .array(let items): items.map { jsonObject($0) }
        case .table(let table): table.mapValues { jsonObject($0) }
        default: NSNull()
        }
    }
}
