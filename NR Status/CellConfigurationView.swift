import SwiftUI

struct CellConfigurationView: View {
    @Binding var cell: NrqlCell
    @Binding var isPresented: Bool
    let isPublished: Bool
    let onUpdatePublished: () -> Void
    var completionScope: () -> LuaCompletion.Scope = { .empty }
    @State private var showsText = false

    private var isDocument: Bool { cell.kind == .config }
    private var format: ChartFormat { ChartFormat.parseMetadata(cell.configurationText) }
    private var chart: String {
        NrqlCellSource.value("chart", in: cell.configurationText).lowercased()
    }
    private var chartType: ChartType? {
        ChartType(rawValue: chart) ?? (chart.isEmpty ? cell.query.resultContainer.flatMap { ChartType.cases(for: $0).first } : nil)
    }
    private var attributes: Set<String> {
        if let attributes = format.attributes { return attributes }
        switch chartType {
        case .line, nil: return ["smoothed", "lines"]
        case .pie: return ["donut", "separated"]
        case .plot: return ["color-facets"]
        default: return []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isDocument ? "Document Configuration" : "Cell Configuration").font(.headline)
                Spacer()
                Button("Close", systemImage: "xmark") { withAnimation { isPresented = false } }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
            if isPublished {
                HStack {
                    Label("Published", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Update Widget", systemImage: "arrow.clockwise", action: onUpdatePublished)
                        .disabled(!cell.canPublishWidget)
                        .help("Update the published workbook snapshot without changing the widget's name")
                        .accessibilityIdentifier("update-published-widget")
                }
            }
            Picker("Editor", selection: $showsText) {
                Text("Settings").tag(false)
                Text("Text").tag(true)
            }
            .pickerStyle(.segmented)
            if showsText {
                Text(isDocument ? "---" : "```cell_config")
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                ConfigurationTextEditor(
                    text: $cell.configurationText, identifier: "cell-configuration-text", completionScope: bindingScope
                )
                    .frame(minHeight: 180)
                    .help("Press Escape to complete binding expressions.")
                Text(isDocument ? "---" : "```").font(.caption.monospaced()).foregroundStyle(.secondary)
            } else {
                settings
            }
            if let error = configurationError {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
            Spacer(minLength: 0)
            if !isDocument, NrqlCellSource(stored: cell.text).configuration != nil {
                HStack {
                    Spacer()
                    Button("Remove Cell Configuration", systemImage: "trash", role: .destructive) {
                        cell.removeConfiguration()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("Remove cell configuration")
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(12)
        .frame(width: 320, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.background.secondary)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isDocument {
                labeledField("Author", text: value("author"))
                labeledField("Description", text: value("description"), axis: .vertical)
            } else {
                labeledField("Title", text: value("title"), identifier: "cell-configuration-title")
            }
            if isDocument {
                bindingSettings
            } else {
                labeledField(
                    cell.kind == .nerdgraph ? "Whole response variable" : "Variable binding",
                    text: value("var"), placeholder: "Result variable", identifier: "cell-result-variable"
                )
                if cell.kind == .nerdgraph { bindingSettings }
            }
            if isDocument {
                labeledField("API Key name", text: value("api-key"), placeholder: "Default if empty")
            }
            if isDocument || (cell.kind != .lua && cell.kind != .nerdgraph) {
                labeledField("Account IDs", text: value("accounts"), placeholder: "Comma separated; default if empty")
            }
            if !isDocument {
                Toggle("Hide query on open and export", isOn: Binding(
                    get: { format.hidesQuery },
                    set: { set("query", values: [$0 ? "hide" : "show"]) }
                ))
                .accessibilityIdentifier("cell-query-visibility")
                .help("Sets the opening and export visibility without changing the current expand/collapse state.")
                displaySelector
                if cell.kind != .nerdgraph && chart != "json" && chart != "none" {
                    chartSettings
                }
            }
        }
    }

    private var bindings: [LuaRuntime.Variable] {
        LuaRuntime.Variable.editableBindings(in: cell.configurationText)
    }

    private var bindingSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Bindings").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Add Binding", systemImage: "plus") {
                    setBindings(bindings + [.init(name: "", expression: "")])
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("add-result-binding")
            }
            ForEach(Array(bindings.indices), id: \.self) { index in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        TextField("Name", text: bindingValue(index, expression: false))
                            .accessibilityIdentifier("binding-name-\(index)")
                        Button("Remove Binding", systemImage: "minus.circle") {
                            var bindings = self.bindings
                            bindings.remove(at: index)
                            setBindings(bindings)
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("remove-binding-\(index)")
                    }
                    ConfigurationTextEditor(
                        text: bindingValue(index, expression: true),
                        identifier: "binding-expression-\(index)", completionScope: bindingScope,
                        isExpression: true
                    )
                    .frame(height: 50)
                    .help(isDocument
                          ? "Lua expression; use config.name to read earlier bindings. Press Escape for completion."
                          : "Lua expression, for example data.actor.account.name. Press Escape for completion.")
                }
            }
        }
    }

    private func bindingValue(_ index: Int, expression: Bool) -> Binding<String> {
        Binding(get: {
            guard bindings.indices.contains(index) else { return "" }
            return expression ? bindings[index].expression ?? "" : bindings[index].name
        }, set: { value in
            var bindings = self.bindings
            guard bindings.indices.contains(index) else { return }
            let previous = bindings[index]
            bindings[index] = .init(
                name: expression ? previous.name : value,
                expression: expression ? value : previous.expression
            )
            setBindings(bindings)
        })
    }

    private func setBindings(_ bindings: [LuaRuntime.Variable]) {
        if let text = try? LuaRuntime.Variable.updatingBindings(bindings, in: cell.configurationText) {
            cell.configurationText = text
        }
    }

    private func bindingScope() -> LuaCompletion.Scope {
        var scope = completionScope()
        if cell.kind == .nerdgraph { scope.response = cell.query.jsonResult }
        return scope
    }

    private var displaySelector: some View {
        HStack {
            Text("Display")
            Spacer()
            Menu {
                displayOption(cell.kind == .nerdgraph ? "Automatic (JSON)" : "Automatic", value: "")
                if cell.kind != .nerdgraph {
                    ForEach(ChartType.allCases, id: \.self) { type in
                        displayOption(type.rawValue.capitalized, value: type.rawValue)
                            .disabled(cell.query.resultContainer.map { !type.isSupported(for: $0) } ?? false)
                    }
                }
                displayOption("JSON", value: "json")
                if cell.kind == .nerdgraph {
                    displayOption("Bindings", value: "bindings")
                }
                displayOption("Hidden", value: "none")
            } label: {
                Text(chart.isEmpty ? (cell.kind == .nerdgraph ? "Automatic (JSON)" : "Automatic")
                    : chart == "json" ? "JSON" : chart == "none" ? "Hidden" : chart.capitalized)
            }
            .menuIndicator(.visible)
            .accessibilityIdentifier("cell-display-selector")
        }
    }

    private func displayOption(_ title: String, value: String) -> some View {
        Button {
            set("chart", values: [value])
        } label: {
            if chart == value {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    @ViewBuilder private var chartSettings: some View {
        labeledField(
            "Chart height (lines)", text: value("height"),
            placeholder: chartType == .billboard ? "Auto (fit content)" : "Auto (20 lines)",
            identifier: "cell-chart-height"
        )
        .help("Enter a positive whole number of display lines, or leave empty for Auto.")
        switch chartType {
        case .line:
            attributeToggle("Stacked", "stacked")
            attributeToggle("Smoothed", "smoothed")
            attributeToggle("Lines", "lines")
            attributeToggle("Points", "points")
        case .pie:
            attributeToggle("Donut", "donut")
            attributeToggle("Separated", "separated")
        case .bar:
            attributeToggle("Pivot Fields & Facets", "pivot")
        case .plot:
            attributeToggle("Color facets", "color-facets")
            attributeToggle("X log scale", "x-log")
            attributeToggle("Y log scale", "y-log")
            field("X axis", "x")
            field("Y axis", "y")
            field("Color field", "color")
            field("Point size field", "size")
        case .billboard:
            attributeToggle("Show gauge", "gauge")
            if attributes.contains("gauge") {
                Picker("Gauge style", selection: parameter("style", default: "linear")) {
                    ForEach(BillboardConfiguration.GaugeStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style.rawValue)
                    }
                }
                labeledField("Maximum value", text: parameter("max", default: "100"))
            }
        case .table:
            EmptyView()
        case nil:
            Text("Choose a chart type or run the cell to configure its automatic chart.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func field(_ title: String, _ name: String) -> some View {
        labeledField(title, text: parameter(name, default: ""))
    }

    private func labeledField(
        _ title: String, text: Binding<String>, placeholder: String? = nil,
        axis: Axis = .horizontal, identifier: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder ?? title, text: text, axis: axis)
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
        }
    }

    private func attributeToggle(_ title: String, _ name: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { attributes.contains(name) },
            set: { enabled in
                var updated = attributes
                if enabled { updated.insert(name) } else { updated.remove(name) }
                if chartType == .line && !updated.contains("lines") && !updated.contains("points") {
                    updated.insert(name == "lines" ? "points" : "lines")
                }
                setAttributes(updated)
            }
        ))
    }

    private func parameter(_ name: String, default fallback: String) -> Binding<String> {
        Binding(get: { format.parameter(name) ?? fallback }, set: { value in
            var updated = attributes.filter { !$0.hasPrefix(name + "(") }
            updated.insert("\(name)(\(value))")
            setAttributes(updated)
        })
    }

    private func setAttributes(_ attributes: Set<String>) {
        // An explicit empty attributes line means all toggles are off, not defaults.
        cell.configurationText = NrqlCellSource.updating(
            "attributes", values: [attributes.sorted().joined(separator: ", ")],
            in: cell.configurationText, includeEmptyValues: true
        )
    }

    private func value(_ key: String) -> Binding<String> {
        Binding(get: {
            let text = NrqlCellSource.value(key, in: cell.configurationText)
            return key == "chart" ? text.lowercased() : text
        }, set: { set(key, values: [$0]) })
    }

    private func set(_ key: String, values: [String]) {
        cell.configurationText = NrqlCellSource.updating(key, values: values, in: cell.configurationText)
    }

    private var configurationError: String? {
        do {
            if isDocument {
                _ = try NrqlConnection.parseDocumentConfig(cell.configurationText)
            } else {
                _ = try NrqlConnection.parse(cell.configurationText)
                if cell.kind == .nerdgraph { _ = try NerdgraphCellSource(stored: cell.text).resultBindings() }
                let height = NrqlCellSource.value("height", in: cell.configurationText)
                if !height.isEmpty && height.lowercased() != "auto" && format.heightInLines == nil {
                    return "Chart height must be a positive whole number of lines, or Auto."
                }
                if let maximum = format.parameter("max"),
                   Double(maximum).map({ $0.isFinite && $0 > 0 }) != true {
                    return "Gauge maximum must be a positive number."
                }
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
