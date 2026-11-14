//
//  NrqlCompletion.swift
//  NR Status
//

import Foundation

/// Source of the account-specific names used for completion.
protocol NrqlMetadataProviding: Sendable {
    func eventTypes() async -> [String]
    func attributes(event: String) async -> [Attribute]
}

/// Works out what can be typed at a position in a query cell and offers matching names.
/// The analysis is purely textual so it stays fast and testable; only the names
/// themselves (event types and attributes) come from NRDB.
enum NrqlCompletion {
    enum Kind: Int {
        case formatKey, formatValue, eventType, attribute, function, keyword, variable, field

        var label: String {
            switch self {
            case .formatKey: "format key"
            case .formatValue: "format value"
            case .eventType: "event type"
            case .attribute: "attribute"
            case .function: "function"
            case .keyword: "keyword"
            case .variable: "variable"
            case .field: "field"
            }
        }
    }

    struct Item: Equatable {
        let name: String
        let kind: Kind
        let detail: String?
        let insertText: String
    }

    enum Context: Equatable {
        case none
        case formatKey
        case formatValue(key: String, type: ChartType?)
        case events
        case attributes(event: String?, keywords: [String])
        case keywords([String])
    }

    struct Analysis: Equatable {
        let context: Context
        // the partial word before the cursor, which a completion replaces
        let prefixRange: NSRange
        let prefix: String
    }

    // MARK: - Static vocabulary

    static let clauseKeywords = [
        "SELECT", "FROM", "WHERE", "FACET", "SINCE", "UNTIL", "LIMIT", "OFFSET", "ORDER BY", "COMPARE WITH",
        "TIMESERIES", "SLIDE BY", "EXTRAPOLATE", "WITH", "SHOW EVENT TYPES"
    ]

    static let whereKeywords = ["AND", "OR", "NOT", "IN", "LIKE", "RLIKE", "IS", "NULL", "TRUE", "FALSE"]


    static let timeWords = [
        "ago", "seconds", "minutes", "hours", "days", "weeks", "months", "today", "yesterday", "now"
    ]

    static let functions = [
        "aggregationendtime", "apdex", "average", "buckets", "cardinality", "count", "derivative", "earliest",
        "filter", "funnel", "histogram", "keyset", "latest", "latestrate", "max", "median", "min", "percentage",
        "percentile", "predictLinear", "rate", "stddev", "stdvar", "sum", "uniqueCount", "uniques",
        "aparse", "capture", "concat", "convert", "decode", "dimensions", "encode", "eventType", "getField",
        "if", "jparse", "length", "lookup", "lower", "mapKeys", "mapValues", "minuteOf", "mod", "position",
        "round", "string", "substring", "toDatetime", "toTimestamp", "upper"
    ]

    // MARK: - Analysis

    private static let blockComment = try! NSRegularExpression(pattern: #"/\*[\s\S]*?\*/"#)
    private static let lineComment = try! NSRegularExpression(pattern: #"//[^\n]*"#)
    private static let clause = try! NSRegularExpression(
        pattern: #"\b(SELECT|FROM|WHERE|FACET|SINCE|UNTIL|LIMIT|OFFSET|ORDER\s+BY|COMPARE\s+WITH|TIMESERIES|SLIDE\s+BY|EXTRAPOLATE|WITH|AS)\b"#,
        options: [.caseInsensitive]
    )
    private static let fromEvent = try! NSRegularExpression(
        pattern: #"\bFROM\s+`?([A-Za-z_][A-Za-z0-9_]*)"#,
        options: [.caseInsensitive]
    )
    private static let typeLine = try! NSRegularExpression(
        pattern: #"^\s*chart:\s*([A-Za-z]+)"#,
        options: [.anchorsMatchLines, .caseInsensitive]
    )

    static func stripComments(_ text: String) -> String {
        var result = text
        for regex in [blockComment, lineComment] {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: ""
            )
        }
        return result
    }

    private static func isWordCharacter(_ char: unichar, allowingDash: Bool) -> Bool {
        guard let scalar = Unicode.Scalar(char) else { return false }
        return CharacterSet.alphanumerics.contains(scalar) || char == 0x5F || char == 0x2E || (allowingDash && char == 0x2D)
    }

    static func analyse(text: String, location: Int, configuration: Bool = false, graphql: Bool = false) -> Analysis {
        let ns = text as NSString
        let cursor = min(max(location, 0), ns.length)
        let upToCursor = ns.substring(to: cursor)

        // an unclosed /* before the cursor means we're inside a block comment
        let open = upToCursor.range(of: "/*", options: .backwards)
        let close = upToCursor.range(of: "*/", options: .backwards)
        var blockStart: String.Index?
        if let open, close == nil || close!.lowerBound < open.lowerBound { blockStart = open.lowerBound }
        let lines = upToCursor.components(separatedBy: "\n")
        let isGraphQLMetadata = graphql
            && lines.dropLast().allSatisfy {
                let trimmed = $0.trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty || trimmed.hasPrefix("#")
            }
            && lines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("#") == true
        let isFormatBlock = isGraphQLMetadata || (!graphql && (blockStart.map { upToCursor[$0...].hasPrefix("/***") } ?? false))

        var start = cursor
        while start > 0, isWordCharacter(ns.character(at: start - 1), allowingDash: isFormatBlock) { start -= 1 }
        var prefixRange = NSRange(location: start, length: cursor - start)
        var prefix = ns.substring(with: prefixRange)

        func result(_ context: Context) -> Analysis {
            Analysis(context: context, prefixRange: prefixRange, prefix: prefix)
        }

        let lineStart = ns.lineRange(for: NSRange(location: start, length: 0)).location
        let lineBeforePrefix = ns.substring(with: NSRange(location: lineStart, length: start - lineStart))

        if blockStart != nil || isGraphQLMetadata {
            guard isFormatBlock else { return result(.none) }
            if let colon = lineBeforePrefix.firstIndex(of: ":") {
                var key = lineBeforePrefix[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                if isGraphQLMetadata { key = key.dropFirst().trimmingCharacters(in: .whitespaces) }
                if isGraphQLMetadata, key == "api_key" { key = "api-key" }
                if key == "api-key" {
                    // A saved name may contain spaces; replace the whole value, not just its last word.
                    let valueStart = lineBeforePrefix.index(after: colon)
                    let leading = lineBeforePrefix[valueStart...].prefix(while: \.isWhitespace).utf16.count
                    let offset = lineStart + lineBeforePrefix[..<valueStart].utf16.count + leading
                    prefixRange = NSRange(location: offset, length: cursor - offset)
                    prefix = ns.substring(with: prefixRange)
                }
                let block = blockStart.map { String(upToCursor[$0...]) } ?? upToCursor
                let type = typeLine.firstMatch(in: block, range: NSRange(block.startIndex..., in: block))
                    .flatMap { Range($0.range(at: 1), in: block) }
                    .flatMap { ChartType(rawValue: block[$0].lowercased()) }
                return result(.formatValue(key: key, type: type))
            }
            var before = lineBeforePrefix.trimmingCharacters(in: .whitespaces)
            if isGraphQLMetadata { before = before.dropFirst().trimmingCharacters(in: .whitespaces) }
            return result(before.isEmpty ? .formatKey : .none)
        }

        if configuration { return result(.none) }

        // no completions inside line comments, strings or quoted names
        if lineBeforePrefix.contains("//") { return result(.none) }
        if lineBeforePrefix.filter({ $0 == "'" }).count % 2 == 1 { return result(.none) }
        if lineBeforePrefix.filter({ $0 == "`" }).count % 2 == 1 { return result(.none) }

        let before = stripComments(ns.substring(to: start))
        let beforeRange = NSRange(before.startIndex..., in: before)
        guard let last = clause.matches(in: before, range: beforeRange).last,
              let keywordRange = Range(last.range(at: 1), in: before)
        else { return result(.keywords(["SELECT", "SHOW EVENT TYPES", "FROM"])) }

        let keyword = before[keywordRange].uppercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let afterKeyword = before[keywordRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)

        // the whole query, apart from the word being typed, decides which clauses are still available
        let others = ns.replacingCharacters(in: prefixRange, with: "")
        let following = followingClauses(in: others)

        switch keyword {
        case "FROM":
            if afterKeyword.isEmpty || afterKeyword.hasSuffix(",") { return result(.events) }
            return result(.keywords(missingCore(in: others) + following))
        case "SELECT":
            return result(.attributes(event: event(in: text), keywords: ["AS"] + missingCore(in: others) + following))
        case "WHERE":
            return result(.attributes(event: event(in: text), keywords: whereKeywords + following))
        case "FACET", "ORDER BY":
            return result(.attributes(event: event(in: text), keywords: ["AS", "CASES"] + following))
        case "SINCE", "UNTIL", "COMPARE WITH", "SLIDE BY", "TIMESERIES":
            return result(.keywords(timeWords + following))
        case "AS", "LIMIT", "OFFSET":
            return result(afterKeyword.isEmpty ? .none : .keywords(missingCore(in: others) + following))
        default:
            return result(.keywords(missingCore(in: others) + following))
        }
    }

    private static func usedClauses(in text: String) -> Set<String> {
        let stripped = stripComments(text)
        let matches = clause.matches(in: stripped, range: NSRange(stripped.startIndex..., in: stripped))
        return Set(matches.compactMap { Range($0.range(at: 1), in: stripped) }.map {
            stripped[$0].uppercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        })
    }

    /// SELECT and FROM, whichever of them the query still lacks.
    private static func missingCore(in text: String) -> [String] {
        let used = usedClauses(in: text)
        return ["SELECT", "FROM"].filter { !used.contains($0) }
    }

    /// Clauses that may come next. They only make sense once the query has both SELECT and FROM, and
    /// each can appear once, except WHERE.
    private static func followingClauses(in text: String) -> [String] {
        let used = usedClauses(in: text)
        guard used.isSuperset(of: ["SELECT", "FROM"]) else { return [] }
        return clauseKeywords.filter { word in
            !["SELECT", "FROM", "SHOW EVENT TYPES"].contains(word) && (word == "WHERE" || !used.contains(word))
        }
    }

    /// The first event type named by a FROM clause, wherever the cursor is.
    static func event(in text: String) -> String? {
        let stripped = stripComments(text)
        guard let match = fromEvent.firstMatch(in: stripped, range: NSRange(stripped.startIndex..., in: stripped)),
              let range = Range(match.range(at: 1), in: stripped)
        else { return nil }
        return String(stripped[range])
    }

    /// Whether the cursor sits where the next word is a name we can list (after a comma, `FROM `, `WHERE `, ...),
    /// so the panel should stay up or come back after a separator is typed.
    static func offersAfterSeparator(text: String, location: Int, configuration: Bool = false) -> Bool {
        let analysis = analyse(text: text, location: location, configuration: configuration)
        guard analysis.prefix.isEmpty else { return false }

        let ns = text as NSString
        let before = ns.substring(to: min(max(location, 0), ns.length)).trimmingCharacters(in: .whitespaces)

        switch analysis.context {
        case .formatValue(let key, _):
            return key == "attributes" || key == "accounts" || before.hasSuffix(":")
        case .events:
            return true
        case .attributes:
            if before.hasSuffix(",") || before.hasSuffix("(") { return true }
            let lastWord = before.split(whereSeparator: { $0.isWhitespace || $0 == "(" }).last?.uppercased()
            return ["SELECT", "WHERE", "FACET", "BY", "AND", "OR", "NOT"].contains(lastWord ?? "")
        case .none, .formatKey, .keywords:
            return false
        }
    }

    // MARK: - Items

    static func items(
        text: String, location: Int, metadata: NrqlMetadataProviding,
        profiles: [NerdgraphProfile] = [], defaultKeyName: String? = nil, configuration: Bool = false, graphql: Bool = false
    ) async -> (items: [Item], range: NSRange) {
        let analysis = analyse(text: text, location: location, configuration: configuration, graphql: graphql)
        var candidates: [Item] = []

        func keywordItems(_ words: [String]) -> [Item] {
            words.map { Item(name: $0, kind: .keyword, detail: nil, insertText: $0) }
        }

        switch analysis.context {
        case .none:
            break
        case .formatKey:
            let keys = graphql ? ["title", "var", "api-key", "chart"]
                : configuration ? ["api-key", "accounts", "author", "description", "var"] : ["title", "var", "chart", "attributes", "api-key", "accounts"]
            candidates = keys.map {
                Item(name: $0, kind: .formatKey, detail: nil, insertText: configuration && !graphql && $0 == "var" ? "var " : "\($0): ")
            }
        case .formatValue(let key, let type):
            var values: [String] = []
            if key == "chart" {
                values = graphql ? ["json", "none"] : ChartType.allCases.map(\.rawValue) + ["json", "none"]
            } else if key == "attributes" {
                values = type.map { ChartFormat.attributeNames[$0] ?? [] }
                    ?? ChartFormat.attributeNames.values.flatMap { $0 }.sorted()
            } else if key == "api-key" {
                values = profiles.map(\.name)
            } else if key == "accounts" {
                let body = NrqlConnection.metadataBody(in: text, allowUnclosed: true)
                let name = NrqlConnection.keyName(in: body) ?? defaultKeyName
                let profile = profiles.first { $0.name.caseInsensitiveCompare(name ?? "") == .orderedSame }
                values = profile?.preferredAccountIds.map(String.init) ?? []
            }
            candidates = values.map { Item(name: $0, kind: .formatValue, detail: nil, insertText: $0) }
        case .events:
            candidates = await metadata.eventTypes().map {
                Item(name: $0, kind: .eventType, detail: nil, insertText: $0)
            }
        case .attributes(let event, let keywords):
            if let event {
                candidates += await metadata.attributes(event: event).map {
                    Item(name: $0.key, kind: .attribute, detail: $0.type, insertText: quoteIfNeeded($0.key))
                }
            }
            candidates += functions.map { Item(name: $0, kind: .function, detail: nil, insertText: "\($0)(") }
            candidates += keywordItems(keywords)
        case .keywords(let words):
            candidates = keywordItems(words)
        }

        let lowered = analysis.prefix.lowercased()
        var seen = Set<String>()
        let matching = candidates
            .filter { lowered.isEmpty || $0.name.lowercased().hasPrefix(lowered) }
            .filter { seen.insert("\($0.kind.rawValue)/\($0.name)").inserted }
            .sorted { ($0.kind.rawValue, $0.name.lowercased()) < ($1.kind.rawValue, $1.name.lowercased()) }
        return (matching, analysis.prefixRange)
    }

    private static func quoteIfNeeded(_ name: String) -> String {
        let plain = name.range(of: #"^[A-Za-z_][A-Za-z0-9_.]*$"#, options: .regularExpression) != nil
        return plain ? name : "`\(name)`"
    }
}
