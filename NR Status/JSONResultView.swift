import SwiftUI

struct JSONResultView: View {
    let value: JSONValue
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
                JSONNodeView(node: JSONNode(key: "$", value: value), search: search)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 160, maxHeight: 520)
        }
        .font(.system(.body, design: .monospaced))
    }
}

struct JSONNode: Identifiable {
    let key: String
    let value: JSONValue
    var id: String { key }

    var children: [JSONNode]? {
        switch value {
        case .object(let fields): fields.sorted { $0.key < $1.key }.map { JSONNode(key: $0.key, value: $0.value) }
        case .array(let values): values.enumerated().map { JSONNode(key: "[\($0.offset)]", value: $0.element) }
        default: nil
        }
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
    @State private var expanded = true

    var body: some View {
        if let children = node.children {
            let childSearch = node.key.localizedCaseInsensitiveContains(search) ? "" : search
            DisclosureGroup(isExpanded: $expanded) {
                ForEach(children.filter { $0.matches(childSearch) }) { child in
                    JSONNodeView(node: child, search: childSearch)
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
