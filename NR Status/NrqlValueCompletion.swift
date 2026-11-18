import Foundation

enum NrqlValueCompletion {
    struct Lookup: Hashable, Sendable {
        let event: String
        let attribute: String
        let timeWindow: String

        var nrql: String {
            "SELECT uniques(\(Self.identifier(attribute)), 100) AS completionValues FROM \(Self.identifier(event)) \(timeWindow)"
        }

        private static func identifier(_ name: String) -> String {
            "`" + name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`") + "`"
        }
    }

    private struct Token {
        enum Kind { case word, string, identifier, symbol }
        let kind: Kind
        let raw: String
        let range: NSRange
        var closed = true
        var upper: String { raw.uppercased() }
        var name: String { kind == .identifier ? decode(String(raw.dropFirst().dropLast())) : raw }
    }

    static func analyse(text: String, location: Int, now: Date = Date()) -> NrqlCompletion.Analysis? {
        let tokens = tokenize(text)
        guard let index = tokens.firstIndex(where: {
            $0.kind == .string && $0.raw.hasPrefix("'")
                && location > $0.range.location
                && location <= NSMaxRange($0.range) - ($0.closed ? 1 : 0)
        }), tokens[..<index].contains(where: { $0.kind == .word && $0.upper == "WHERE" }),
              tokens.filter({ $0.kind == .word && $0.upper == "SELECT" }).count == 1,
              let from = tokens.firstIndex(where: { $0.kind == .word && $0.upper == "FROM" }),
              tokens.filter({ $0.kind == .word && $0.upper == "FROM" }).count == 1,
              from + 1 < tokens.count else { return nil }
        let event = tokens[from + 1]
        guard event.kind == .word || event.kind == .identifier,
              event.closed, from + 2 == tokens.count || tokens[from + 2].raw != "," else { return nil }

        var attributeIndex: Int
        if index >= 2, ["=", "!=", "<>"].contains(tokens[index - 1].raw) {
            attributeIndex = index - 2
        } else {
            var before = index - 1
            while before >= 1, tokens[before].raw == ",", tokens[before - 1].kind == .string,
                  tokens[before - 1].closed { before -= 2 }
            guard before >= 2, tokens[before].raw == "(", tokens[before - 1].upper == "IN" else { return nil }
            attributeIndex = before - 2
            if tokens[attributeIndex].upper == "NOT" { attributeIndex -= 1 }
        }
        guard attributeIndex >= 1 else { return nil }
        let attribute = tokens[attributeIndex]
        guard attribute.kind == .word || attribute.kind == .identifier, attribute.closed,
              ["WHERE", "AND", "OR", "NOT", "("].contains(tokens[attributeIndex - 1].upper),
              let window = timeWindow(tokens: tokens, now: now) else { return nil }
        let literal = tokens[index]
        let start = literal.range.location + 1
        let contentEnd = NSMaxRange(literal.range) - (literal.closed ? 1 : 0)
        let prefix = (text as NSString).substring(with: NSRange(location: start, length: location - start))
        return NrqlCompletion.Analysis(
            context: .values(Lookup(event: event.name, attribute: attribute.name, timeWindow: window), closeQuote: !literal.closed),
            prefixRange: NSRange(location: start, length: contentEnd - start),
            prefix: decode(prefix)
        )
    }

    static func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    private static func decode(_ value: String) -> String {
        var result = ""
        var escaped = false
        for character in value {
            if escaped {
                switch character {
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                default: result.append(character)
                }
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else {
                result.append(character)
            }
        }
        if escaped { result.append("\\") }
        return result.replacingOccurrences(of: "''", with: "'")
    }

    private static func tokenize(_ text: String) -> [Token] {
        let text = text as NSString
        var tokens: [Token] = []
        var index = 0
        func at(_ offset: Int) -> unichar { offset < text.length ? text.character(at: offset) : 0 }
        while index < text.length {
            let character = at(index)
            if let scalar = Unicode.Scalar(character), CharacterSet.whitespacesAndNewlines.contains(scalar) {
                index += 1
                continue
            }
            if (character == 47 && at(index + 1) == 47) || (character == 45 && at(index + 1) == 45) {
                while index < text.length, at(index) != 10 { index += 1 }
                continue
            }
            if character == 47 && at(index + 1) == 42 {
                index += 2
                while index < text.length, !(at(index) == 42 && at(index + 1) == 47) { index += 1 }
                index = min(index + 2, text.length)
                continue
            }
            let start = index
            var kind = Token.Kind.symbol
            var closed = true
            if character == 39 || character == 34 || character == 96 {
                kind = character == 96 ? .identifier : .string
                closed = false
                index += 1
                while index < text.length {
                    if at(index) == 92 {
                        index = min(index + 2, text.length)
                    } else if at(index) == character {
                        if at(index + 1) == character { index += 2; continue }
                        index += 1
                        closed = true
                        break
                    } else { index += 1 }
                }
            } else if let scalar = Unicode.Scalar(character),
                      CharacterSet.alphanumerics.contains(scalar) || character == 95 {
                kind = .word
                index += 1
                while index < text.length {
                    let next = at(index)
                    guard let scalar = Unicode.Scalar(next),
                          CharacterSet.alphanumerics.contains(scalar) || next == 95 || next == 46 else { break }
                    index += 1
                }
            } else {
                index += 1
                if [33, 60, 62].contains(character), at(index) == 61 || (character == 60 && at(index) == 62) {
                    index += 1
                }
            }
            let range = NSRange(location: start, length: index - start)
            tokens.append(Token(kind: kind, raw: text.substring(with: range), range: range, closed: closed))
        }
        return tokens
    }

    private static func timeWindow(tokens: [Token], now: Date) -> String? {
        let boundaries: Set<String> = [
            "SELECT", "FROM", "WHERE", "FACET", "SINCE", "UNTIL", "LIMIT", "OFFSET", "ORDER",
            "COMPARE", "TIMESERIES", "SLIDE", "EXTRAPOLATE", "WITH", "AS"
        ]
        var depth = 0
        var clauses: [String: [Token]] = [:]
        for (index, token) in tokens.enumerated() {
            if token.raw == "(" { depth += 1 }
            if token.raw == ")" { depth -= 1 }
            guard depth == 0, token.kind == .word, ["SINCE", "UNTIL", "WITH"].contains(token.upper) else { continue }
            if token.upper == "WITH", index > 0, tokens[index - 1].upper == "COMPARE" { continue }
            guard clauses[token.upper] == nil else { return nil }
            let values = tokens.dropFirst(index + 1).prefix {
                !($0.kind == .word && boundaries.contains($0.upper)) && $0.raw != ";"
            }
            clauses[token.upper] = Array(values)
        }
        var timezone = TimeZone(secondsFromGMT: 0)!
        var timezoneClause = ""
        if let with = clauses["WITH"] {
            guard with.count == 2, with[0].upper == "TIMEZONE", with[1].kind == .string, with[1].closed,
                  let zone = TimeZone(identifier: String(with[1].raw.dropFirst().dropLast())) else { return nil }
            timezone = zone
            timezoneClause = " WITH TIMEZONE \(with[1].raw)"
        }
        func expression(_ tokens: [Token]) -> String? {
            let text = tokens.map(\.raw).joined(separator: " ")
            return timestamp(text, now: now, timezone: timezone) == nil ? nil : text
        }
        let until: String?
        if let tokens = clauses["UNTIL"] {
            guard let value = expression(tokens) else { return nil }
            until = value
        } else { until = nil }
        let since: String
        if let tokens = clauses["SINCE"] {
            guard let value = expression(tokens) else { return nil }
            since = value
        } else if let until {
            guard let end = timestamp(until, now: now, timezone: timezone) else { return nil }
            let offset = relativeOffset(until)
            let milliseconds = offset.map { ($0 + 3600) * 1000 } ?? (end.timeIntervalSince1970 - 3600) * 1000
            guard milliseconds.isFinite, milliseconds > Double(Int64.min), milliseconds < Double(Int64.max) else { return nil }
            since = String(Int64(milliseconds)) + (offset == nil ? "" : " milliseconds ago")
        } else {
            since = "1 hour ago"
        }
        return "SINCE \(since)" + (until.map { " UNTIL \($0)" } ?? "") + timezoneClause
    }

    private static func relativeOffset(_ expression: String) -> TimeInterval? {
        let text = expression.lowercased()
        if text == "now" { return 0 }
        let parts = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let units: [String: Double] = [
            "millisecond": 0.001, "second": 1, "minute": 60, "hour": 3600,
            "day": 86400, "week": 604800, "month": 2592000, "quarter": 7862400, "year": 31536000
        ]
        if parts.count == 3, let count = UInt(parts[0]), parts[2] == "ago",
           let seconds = units[parts[1].hasSuffix("s") ? String(parts[1].dropLast()) : parts[1]] {
            return Double(count) * seconds
        }
        return nil
    }

    private static func timestamp(_ expression: String, now: Date, timezone: TimeZone) -> Date? {
        let text = expression.lowercased()
        if let offset = relativeOffset(expression) { return now.addingTimeInterval(-offset) }
        if text.count >= 13, let value = Int64(text) { return Date(timeIntervalSince1970: Double(value) / 1000) }
        let parts = text.split(whereSeparator: \.isWhitespace).map(String.init)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        calendar.firstWeekday = 2
        let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        if let day = parts.first, ["today", "yesterday"].contains(day) || weekdays.contains(day) {
            let daysAgo = weekdays.firstIndex(of: day).map { (calendar.component(.weekday, from: now) - 1 - $0 + 7) % 7 }
                ?? (day == "yesterday" ? 1 : 0)
            guard let start = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)) else { return nil }
            if parts.count == 1 { return start }
            guard parts.count == 3, parts[1] == "at",
                  parts[2].range(of: #"^'\d{2}:\d{2}(?::\d{2})?'$"#, options: .regularExpression) != nil else { return nil }
            let time = parts[2].dropFirst().dropLast().split(separator: ":").compactMap { Int($0) }
            guard time.count >= 2, time[0] < 24, time[1] < 60, time.count == 2 || time[2] < 60 else { return nil }
            return calendar.date(bySettingHour: time[0], minute: time[1], second: time.count == 3 ? time[2] : 0, of: start)
        }
        if parts.count == 2, ["this", "last"].contains(parts[0]) {
            let components: [String: Calendar.Component] = [
                "hour": .hour, "day": .day, "week": .weekOfYear, "month": .month, "quarter": .quarter, "year": .year
            ]
            guard let component = components[parts[1]], let start = calendar.dateInterval(of: component, for: now)?.start else { return nil }
            return parts[0] == "this" ? start : calendar.date(byAdding: component, value: -1, to: start)
        }
        guard expression.count >= 2, ["'", "\""].contains(expression.prefix(1)),
              expression.suffix(1) == expression.prefix(1) else { return nil }
        let value = String(expression.dropFirst().dropLast())
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.isLenient = false
        formatter.defaultDate = calendar.startOfDay(for: now)
        for format in [
            "yyyy-MM-dd'T'HH:mmXXXXX", "yyyy-MM-dd HH:mm:ss.SSS Z", "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd HH:mm:ss.SSS", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd",
            "HH:mm:ss", "HH:mm"
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}
