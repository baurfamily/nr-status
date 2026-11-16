import SwiftUI

struct JSONResultView: View {
    let value: JSONValue
    var onAddBinding: ((JSONNode) -> Void)?
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Find in JSON", text: $search)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Find in JSON results")
            ForEach(Array(value.graphQLErrors.enumerated()), id: \.offset) { _, message in
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
            ScrollView([.vertical, .horizontal]) {
                JSONNodeView(node: JSONNode(key: "$", value: value), search: search, onAddBinding: onAddBinding)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 160, maxHeight: 520)
        }
        .font(.system(.body, design: .monospaced))
    }
}

struct JSONNode: Identifiable {
    enum PathComponent {
        case field(String), index(Int)
    }

    let key: String
    let value: JSONValue
    var path: [PathComponent] = []
    var id: String { key }

    var children: [JSONNode]? {
        switch value {
        case .object(let fields): fields.sorted { $0.key < $1.key }.map {
            JSONNode(key: $0.key, value: $0.value, path: path + [.field($0.key)])
        }
        case .array(let values): values.enumerated().map {
            JSONNode(key: "[\($0.offset)]", value: $0.element, path: path + [.index($0.offset + 1)])
        }
        default: nil
        }
    }

    var canBind: Bool {
        path.isEmpty || bindingExpression != nil
    }

    var bindingExpression: String? {
        guard case .field(let root) = path.first, ["data", "errors", "extensions"].contains(root) else { return nil }
        return root + path.dropFirst().map {
            switch $0 {
            case .field(let field):
                if LuaRuntime.Variable.isIdentifier(field) {
                    return "." + field
                }
                return "[\(BindingResult.luaString(field))]"
            case .index(let index): return "[\(index)]"
            }
        }.joined()
    }

    var suggestedBindingName: String {
        let lastField = path.reversed().compactMap { component -> String? in
            if case .field(let name) = component { return name }
            return nil
        }.first ?? "response"
        let name = lastField.replacingOccurrences(of: "[^A-Za-z0-9_]", with: "_", options: .regularExpression)
        if LuaRuntime.Variable.isIdentifier(name) { return name }
        return "value_" + name
    }

    var summary: String {
        switch value {
        case .object(let fields): return "{ \(fields.count) fields }"
        case .array(let values): return "[ \(values.count) items ]"
        default:
            do { return try value.encodedText() }
            catch { return "Invalid JSON value: \(error.localizedDescription)" }
        }
    }

    func displayValue(isExpanded: Bool) -> String? {
        guard isExpanded else { return summary }
        switch value {
        case .object(let fields): return fields.isEmpty ? "{}" : nil
        case .array(let values): return values.isEmpty ? "[]" : nil
        default: return summary
        }
    }

    func matches(_ search: String) -> Bool {
        search.isEmpty || key.localizedCaseInsensitiveContains(search)
            || summary.localizedCaseInsensitiveContains(search)
            || children?.contains(where: { $0.matches(search) }) == true
    }
}

private struct JSONNodeView: View {
    let node: JSONNode
    let search: String
    var onAddBinding: ((JSONNode) -> Void)?
    @State private var expanded = true

    var body: some View {
        if let children = node.children {
            let childSearch = node.key.localizedCaseInsensitiveContains(search) ? "" : search
            DisclosureGroup(isExpanded: $expanded) {
                ForEach(children.filter { $0.matches(childSearch) }) { child in
                    JSONNodeView(node: child, search: childSearch, onAddBinding: onAddBinding)
                }
            } label: {
                label
            }
            .disclosureGroupStyle(JSONDisclosureGroupStyle())
            .onChange(of: search) { if !search.isEmpty { expanded = true } }
        } else if node.matches(search) {
            label.padding(.leading, 18)
        }
    }

    private var label: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(node.key + ":").foregroundStyle(.secondary)
            if let value = node.displayValue(isExpanded: expanded) {
                Text(value).textSelection(.enabled)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .contextMenu {
            if let onAddBinding, node.canBind {
                Button("Add Binding to This Value…") { onAddBinding(node) }
            }
        }
    }
}

private struct JSONDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                Button {
                    configuration.isExpanded.toggle()
                } label: {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 12, height: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(configuration.isExpanded ? "Collapse JSON node" : "Expand JSON node")
                configuration.label
            }
            if configuration.isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    configuration.content
                }
                .padding(.leading, 20)
            }
        }
    }
}
