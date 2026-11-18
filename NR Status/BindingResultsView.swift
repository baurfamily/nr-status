import AppKit
import SwiftUI

struct BindingResultsView: View {
    let bindings: [BindingResult]
    var resultContainer: NrdbResultContainer?

    var body: some View {
        if bindings.isEmpty {
            Text("No bound values to display. Add bindings in cell configuration or right-click a JSON value, then run the cell.")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 12) {
                ForEach(bindings) { binding in
                    GridRow(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(binding.namespace == "config" ? "config.\(binding.name)" : binding.name)
                                .fontWeight(.medium).textSelection(.enabled)
                            if binding.expression != nil || binding.literalValue != nil {
                                Text(verbatim: binding.sourceDescription).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .help(binding.sourceDescription)
                        .contextMenu {
                            Button("Copy Reference") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(binding.reference, forType: .string)
                            }
                        }
                        BindingValueView(binding: binding, resultContainer: resultContainer)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct BindingValueView: View {
    let binding: BindingResult
    var resultContainer: NrdbResultContainer?
    @State private var showsValue = false

    var body: some View {
        if binding.value != nil || resultContainer != nil {
            Button { showsValue = true } label: {
                Text(binding.summary).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .help(resultContainer == nil ? "Inspect the bound value" : "Inspect the result table")
            .popover(isPresented: $showsValue) {
                if let value = binding.value {
                    JSONResultView(value: value).padding().frame(width: 500, height: 400)
                } else if let resultContainer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(binding.name).font(.headline)
                        TableChart(config: ChartConfiguration(resultContainer: resultContainer))
                    }
                    .padding()
                    .frame(width: 640, height: 360)
                }
            }
        } else {
            Text(binding.summary)
                .foregroundStyle(binding.error == nil ? Color.secondary : .red)
                .lineLimit(3)
                .help(binding.summary)
                .textSelection(.enabled)
        }
    }
}

struct AddResultBindingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var cell: NrqlCell
    let node: JSONNode
    let existingNames: [String]
    @State private var name = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Result Binding").font(.headline)
            Text(node.bindingExpression ?? "The complete JSON response")
                .font(.system(.body, design: .monospaced)).textSelection(.enabled)
            TextField("Variable name", text: $name)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
            Text("Available as results.<name> after you run the cell again.")
                .font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Add Binding") {
                    do {
                        guard !existingNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                            throw NrqlConnection.ConfigurationError(message: "A binding with this name already exists in this workbook.")
                        }
                        try cell.addResultBinding(name: name, expression: node.bindingExpression)
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            let base = node.suggestedBindingName
            name = base
            var suffix = 2
            while existingNames.contains(name) {
                name = "\(base)\(suffix)"
                suffix += 1
            }
        }
    }
}
