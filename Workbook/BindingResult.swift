import Foundation

struct BindingResult: Identifiable, Equatable, Sendable {
    let name: String
    var expression: String?
    var value: JSONValue?
    var error: String?
    var preview: String?
    var namespace = "results"
    var literalValue: String?

    var id: String { name }

    var sourceDescription: String {
        expression ?? literalValue.map { "value: \($0)" } ?? (namespace == "config" ? "(document setting)" : "(whole response)")
    }

    var summary: String {
        if let error { return error }
        if let preview { return preview }
        guard let value else { return "Not bound" }
        switch value {
        case .array(let values): return "\(values.count) items"
        case .object(let fields): return "\(fields.count) fields"
        default: return (try? value.encodedText()) ?? "Unable to display value"
        }
    }

    var reference: String {
        if LuaRuntime.Variable.isIdentifier(name) {
            return "\(namespace).\(name)"
        }
        return "\(namespace)[\(Self.luaString(name))]"
    }

    static func luaString(_ string: String) -> String {
        "\"" + string.unicodeScalars.map { scalar in
            switch scalar {
            case "\"": return "\\\""
            case "\\": return "\\\\"
            case _ where scalar.value < 32 || scalar.value == 127:
                return String(format: "\\%03d", scalar.value)
            default: return String(scalar)
            }
        }.joined() + "\""
    }
}
