import SwiftUI

struct WorkbookBindingGroup: Identifiable {
    let id: String
    let title: String
    let bindings: [BindingResult]
    var warning: String?
    var cellID: UUID?
    var resultContainer: NrdbResultContainer?

    static func groups(in document: NRQL_EditorDocument, profiles: NerdgraphProfiles.Settings) -> [Self] {
        let config: [BindingResult]
        do {
            let connection = try document.connection.get().effectiveConfiguration(profiles: profiles)
            let value = try JSONValue(luaValue: LuaRuntime.run("return config", config: connection).value)
            if case .object(var fields) = value {
                if fields["api_key"] == nil { fields["api_key"] = .null }
                config = fields.keys.sorted().map { BindingResult(name: $0, value: fields[$0], namespace: "config") }
            } else {
                config = []
            }
        } catch {
            config = [BindingResult(name: "config", error: error.localizedDescription, namespace: "config")]
        }
        var groups = [Self(
            id: "config", title: "Document Configuration", bindings: config,
            cellID: document.cells.first(where: { $0.kind == .config })?.id
        )]
        let stale = document.staleCellIds(profiles: profiles)
        let names = document.cells.flatMap(\.query.resultNames)
        for cell in document.cells {
            var bindings: [BindingResult] = []
            if cell.kind == .nerdgraph {
                bindings = cell.query.inspectedBindings
                let declarations = NerdgraphCellSource(stored: cell.text)
                do {
                    for binding in try declarations.resultBindings() where !bindings.contains(where: { $0.name == binding.name }) {
                        bindings.append(BindingResult(name: binding.name, expression: binding.expression))
                    }
                } catch {
                    bindings.append(BindingResult(name: "Bindings", error: error.localizedDescription))
                }
            } else if cell.kind == .nrql || cell.kind == .lua, let name = cell.query.name {
                bindings = [BindingResult(
                    name: name,
                    preview: cell.query.resultContainer.map { $0.data.count == 1 ? "1 row" : "\($0.data.count) rows" }
                )]
            }
            guard !bindings.isEmpty else { continue }
            var warnings: [String] = []
            if let error = cell.query.errorMessage { warnings.append(error) }
            if cell.query.failedBindingResponse != nil {
                warnings.append("Diagnostic values only; no bindings from this run are available to other cells.")
            } else if cell.query.isRunning {
                warnings.append("Running…")
            } else if !cell.query.hasResult {
                warnings.append("Run this cell to bind its results.")
            } else if stale.contains(cell.id) {
                warnings.append("Out of date. Run this cell to refresh its bindings.")
            }
            if bindings.contains(where: { binding in names.filter { $0 == binding.name }.count > 1 }) {
                warnings.append("Duplicate result names are ambiguous. Give each binding a unique name.")
            }
            groups.append(Self(
                id: cell.id.uuidString, title: cell.query.title, bindings: bindings,
                warning: warnings.isEmpty ? nil : warnings.joined(separator: "\n"),
                cellID: cell.id, resultContainer: cell.query.resultContainer
            ))
        }
        return groups
    }
}

struct WorkbookBindingsView: View {
    let document: NRQL_EditorDocument
    let profiles: NerdgraphProfiles.Settings
    var onJumpToCell: (UUID) -> Void = { _ in }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("Workbook Bindings").font(.headline)
                Text("Use config.<name> for document variables and results.<name> for cell bindings. Click a value to inspect it, or a row count to open its result table.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(WorkbookBindingGroup.groups(in: document, profiles: profiles)) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(group.title).font(.subheadline.bold())
                            Spacer(minLength: 8)
                            if let id = group.cellID {
                                Button("Jump to Cell", systemImage: "arrow.up.forward") { onJumpToCell(id) }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(.borderless)
                                    .help("Jump to \(group.title)")
                                    .accessibilityIdentifier("jump-to-cell-\(id.uuidString)")
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            if let warning = group.warning {
                                Text(warning).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                            }
                            BindingResultsView(bindings: group.bindings, resultContainer: group.resultContainer)
                        }
                        .padding(.leading, 12)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .accessibilityIdentifier("workbook-bindings-inspector")
    }
}
