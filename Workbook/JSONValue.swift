import Foundation
import LuaSwift

indirect enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Decimal)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Decimal.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    subscript(key: String) -> JSONValue? {
        guard case .object(let fields) = self else { return nil }
        return fields[key]
    }

    var luaValue: LuaValue {
        switch self {
        case .object(let fields): .table(fields.mapValues(\.luaValue))
        case .array(let values): .array(values.map(\.luaValue))
        case .string(let value): .string(value)
        case .number(let value): .number(NSDecimalNumber(decimal: value).doubleValue)
        case .bool(let value): .bool(value)
        case .null: .nil
        }
    }

    init(luaValue: LuaValue) throws {
        switch luaValue {
        case .table(let fields): self = .object(try fields.mapValues { try JSONValue(luaValue: $0) })
        case .array(let values): self = .array(try values.map { try JSONValue(luaValue: $0) })
        case .string(let value): self = .string(value)
        case .number(let value):
            guard value.isFinite else {
                throw NrqlConnection.ConfigurationError(message: "JSON cannot contain non-finite numbers.")
            }
            self = .number(Decimal(value))
        case .bool(let value): self = .bool(value)
        case .nil: self = .null
        default: throw NrqlConnection.ConfigurationError(message: "GraphQL variables cannot contain Lua functions or reference values.")
        }
    }

    func encodedText(pretty: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }

    var graphQLErrors: [String] {
        guard case .array(let errors) = self["errors"] else { return [] }
        return errors.compactMap {
            guard case .string(let message) = $0["message"] else { return nil }
            return message
        }
    }
}
