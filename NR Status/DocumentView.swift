//
//  DocumentView.swift
//  NRQL Editor
//
//  Created by Eric Baur on 10/14/24.
//

import SwiftUI
import CodeEditorView
import LanguageSupport

/// A notebook-style document: each query is a cell with its results below it.
struct DocumentView: View {
    @Binding var document: NRQL_EditorDocument
    @AppStorage("nerdgraphProfiles", store: NerdgraphConfig.sharedDefaults) private var profileSettingsData = Data()
    @State private var profileSettings = NerdgraphProfiles.Settings()
    @State private var configurationError: String?
    @State private var configRevealRequest = UUID()

    var body: some View {
        ScrollViewReader { proxy in
            notebook
                .onChange(of: configRevealRequest) {
                    if let id = document.focusedCellId {
                        withAnimation { proxy.scrollTo(id, anchor: .top) }
                    }
                }
        }
        .toolbar { documentToolbar }
        .task(id: profileSettingsData) {
            do {
                profileSettings = try NerdgraphProfiles.shared.load()
            } catch {
                configurationError = error.localizedDescription
            }
        }
        .alert("Document Configuration", isPresented: Binding(
            get: { configurationError != nil },
            set: { if !$0 { configurationError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(configurationError ?? "")
        }
    }

    private var notebook: some View {
        let stale = document.staleCellIds(profiles: profileSettings)
        let readingBelow = document.readingBelowCellIds
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if case .failure(let error) = document.connection {
                    Text(error.localizedDescription).foregroundStyle(.red)
                }
                ForEach($document.cells) { $cell in
                    CellView(
                        cell: $cell,
                        isFocused: document.focusedCellId == cell.id,
                        isStale: stale.contains(cell.id),
                        readsFromBelow: readingBelow.contains(cell.id),
                        onFocus: { document.focusedCellId = cell.id },
                        completionScope: { document.completionScope(excluding: cell.id) },
                        connectionSource: { document.connection },
                        onRun: { document.runCell(cell.id) },
                        pendingTitles: document.pendingDependencies(for: cell.id, stale: stale).map(\.query.title),
                        canPerform: { document.canPerform($0, on: cell.id) },
                        onAction: { document.perform($0, on: cell.id) }
                    )
                }
                HStack {
                    Button("Add Markdown", systemImage: "text.alignleft") {
                        document.addCell(after: document.cells.last?.id, kind: .markdown)
                    }
                    Button("Add Query", systemImage: "plus") {
                        document.addCell(after: document.cells.last?.id)
                    }
                    Button("Add Script", systemImage: "curlybraces") {
                        document.addCell(after: document.cells.last?.id, kind: .lua)
                    }
                    Button("Add Nerdgraph", systemImage: "point.3.connected.trianglepath.dotted") {
                        document.addCell(after: document.cells.last?.id, kind: .nerdgraph)
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding()
        }
        // a click on empty space leaves the focused cell, which renders a Markdown cell
        .background(Color.clear.contentShape(Rectangle()).onTapGesture { document.focusedCellId = nil })
    }

    @ToolbarContentBuilder private var documentToolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button("Collapse All", systemImage: "rectangle.compress.vertical") { document.setAllCollapsed(true) }
                .help("Hide code and document configuration")
            Button("Expand All", systemImage: "rectangle.expand.vertical") { document.setAllCollapsed(false) }
                .help("Show code and document configuration")
        }
        if #available(macOS 26.0, *) {
            ToolbarSpacer(.fixed)
        }
        ToolbarItem {
            ControlGroup("Document Config") {
                Button("Document Config", systemImage: "gearshape") {
                    document.addConfiguration()
                    configRevealRequest = UUID()
                }
                .help("Show and expand the document configuration")
                keyMenu
                accountsMenu
            }
            .labelStyle(.iconOnly)
        }
        if #available(macOS 26.0, *) {
            ToolbarSpacer(.flexible)
        }
        ToolbarItemGroup {
            Button("Clear Results", systemImage: "eraser") { document.clearResults() }
                .help("Clear all cached results and charts in this document")
            Button("Run All", systemImage: "play.fill") { document.runAllQueries() }
                .help("Run every query in this document")
                .disabled(!document.cells.contains { $0.isRunnable })
        }
    }

    private var selectedConnection: NrqlConnection? {
        if case .success(let options) = document.connection { return options }
        return nil
    }

    private var selectedKeyName: String? {
        guard let name = selectedConnection?.apiKeyName else { return nil }
        return profileSettings.profiles.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.name ?? name
    }

    private var selectedProfile: NerdgraphProfile? {
        profileSettings.profiles.first {
            if let selectedKeyName { return $0.name == selectedKeyName }
            return $0.id == profileSettings.defaultProfileID
        }
    }

    private var keyMenu: some View {
        Menu {
            Picker("API key", selection: Binding(
                get: { selectedKeyName },
                set: { name in changeConfiguration { try document.setDefaultApiKey(name) } }
            )) {
                Text("Default (from Settings)").tag(String?.none)
                ForEach(profileSettings.profiles) { profile in
                    Text(profile.name).tag(Optional(profile.name))
                }
                if let name = selectedKeyName, !profileSettings.profiles.contains(where: { $0.name == name }) {
                    Text("\(name) (unavailable)").tag(Optional(name))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("API Key", systemImage: "key")
                .labelStyle(.iconOnly)
        }
        .menuIndicator(.visible)
        .disabled(selectedConnection == nil)
        .accessibilityValue(selectedConnection == nil ? "Invalid configuration" : selectedKeyName == nil ? "Default" : "Custom")
        .help("Override the app's default API key for this document")
    }

    private var accountCandidates: [Int] {
        Array(Set((selectedProfile?.preferredAccountIds ?? []) + (selectedConnection?.accountIds ?? []))).sorted()
    }

    private var accountsMenu: some View {
        Menu {
            Button {
                changeConfiguration { try document.setDefaultAccountIds(nil) }
            } label: {
                if selectedConnection?.accountIds == nil {
                    Label("Default", systemImage: "checkmark")
                } else {
                    Text("Default")
                }
            }
            Divider()
            ForEach(accountCandidates, id: \.self) { id in
                Toggle(String(id), isOn: Binding(
                    get: { selectedConnection?.accountIds?.contains(id) == true },
                    set: { selectAccount(id, selected: $0) }
                ))
            }
            if accountCandidates.isEmpty {
                Text("Add preferred accounts in Settings or enter IDs in the config block.")
            }
        } label: {
            Label("Accounts", systemImage: "building.2")
                .labelStyle(.iconOnly)
        }
        .menuIndicator(.visible)
        .disabled(selectedConnection == nil)
        .accessibilityValue(selectedConnection == nil ? "Invalid configuration" : selectedConnection?.accountIds == nil ? "Default" : "Custom")
        .help("Default uses the selected key's preferred accounts. Select multiple accounts to override.")
    }

    private func selectAccount(_ id: Int, selected: Bool) {
        changeConfiguration {
            var ids = try document.connection.get().accountIds ?? []
            if selected {
                if !ids.contains(id) { ids.append(id) }
            } else {
                ids.removeAll { $0 == id }
            }
            try document.setDefaultAccountIds(ids.isEmpty ? nil : ids)
        }
    }

    private func changeConfiguration(_ update: () throws -> Void) {
        do {
            try update()
        } catch {
            configurationError = error.localizedDescription
        }
    }
}

struct CellView: View {
    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    @Binding var cell: NrqlCell
    let isFocused: Bool
    let isStale: Bool
    let readsFromBelow: Bool
    let onFocus: () -> Void
    let completionScope: () -> LuaCompletion.Scope
    let connectionSource: () -> Result<NrqlConnection, Error>
    let onRun: () -> Void
    let pendingTitles: [String]
    let canPerform: (NRQL_EditorDocument.CellAction) -> Bool
    let onAction: (NRQL_EditorDocument.CellAction) -> Void

    @State private var position: CodeEditor.Position = .init(selections: [NSMakeRange(0, 0)], verticalScrollPosition: 0)
    @State private var messages: Set<TextLocated<Message>> = Set()
    @State private var languageService = NrqlLanguageService()
    @State private var luaService = NrqlLanguageService(language: .lua)
    @State private var configService = NrqlLanguageService(language: .config)
    @State private var graphqlService = NrqlLanguageService(language: .graphql)
    @State private var variablesService = NrqlLanguageService(language: .variables)
    @State private var variablesPosition: CodeEditor.Position = .init(selections: [NSMakeRange(0, 0)], verticalScrollPosition: 0)
    @State private var showsGraphqlSchema = false
    @State private var graphqlCompletionError: String?
    // the chart settings inspector is hidden until asked for
    @State private var showsChartSettings = false
    @State private var showsSentQuery = false
    @State private var showsWarnings = false
    // what the editor shows while typing; copied into the document after a pause so each
    // keystroke doesn't refresh the editor (which would break its undo coalescing)
    @State private var draft: String?

    private var liveText: String { draft ?? cell.editorText }

    private var warnings: [String] {
        var messages: [String] = []
        if isStale {
            messages.append("Out of date: connection settings or an upstream result changed. Run this cell to refresh it and any stale dependencies.")
        }
        if !pendingTitles.isEmpty {
            messages.append("Running this cell will also run: \(pendingTitles.joined(separator: ", "))")
        }
        if readsFromBelow {
            messages.append("Reads results from a cell below; consider moving it.")
        }
        return messages
    }


    // the editor scrolls itself, so give it room for the lines it has
    private var editorHeight: CGFloat {
        CGFloat(max(liveText.split(separator: "\n", omittingEmptySubsequences: false).count, 2)) * 18 + 16
    }

    private var isRenderedMarkdown: Bool { cell.kind == .markdown && !isFocused }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if cell.kind == .nerdgraph {
                HStack(alignment: .top, spacing: 16) {
                    if !cell.isCollapsed {
                        if showsGraphqlSchema {
                            NerdgraphSchemaView(
                                loadID: NerdgraphCellSource(editorText: liveText).metadata
                                    + ((try? connectionSource().get().apiKeyName) ?? ""),
                                load: { try await graphqlService.graphqlSchema() },
                                onInsert: insertGraphqlField
                            )
                            .frame(width: 250)
                        }
                        nerdgraphEditors
                            .frame(maxWidth: .infinity)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("JSON Results").font(.caption).foregroundStyle(.secondary)
                        CellResultView(query: cell.query, configurationShowing: $showsChartSettings)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if isRenderedMarkdown {
                renderedMarkdown
            } else if !cell.isCollapsed || cell.kind == .markdown {
                editor
            }

            if cell.kind == .nrql || cell.kind == .lua {
                CellResultView(query: cell.query, configurationShowing: $showsChartSettings)
            }
        }
        .padding(8)
        .onChange(of: cell.kind) { draft = nil }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isRenderedMarkdown ? Color.clear : isFocused ? Color.accentColor : Color.secondary.opacity(0.3),
                    lineWidth: isFocused ? 2 : 1
                )
        )
    }

    private var nerdgraphEditors: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GraphQL").font(.caption).foregroundStyle(.secondary)
            nerdgraphEditor(variables: false)
            Text("Variables (JSON; {{ Lua expression }})").font(.caption).foregroundStyle(.secondary)
            nerdgraphEditor(variables: true)
            if let graphqlCompletionError {
                Label("Completion unavailable: \(graphqlCompletionError)", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .task(id: draft) {
            guard let pending = draft, pending != cell.editorText else { return }
            try? await Task.sleep(for: .milliseconds(300))
            if !Task.isCancelled { cell.editorText = pending }
        }
        .onDisappear {
            if let pending = draft, pending != cell.editorText { cell.editorText = pending }
            draft = nil
        }
        .onChange(of: cell.text) {
            if let draft, draft != cell.editorText { self.draft = nil }
            if cell.query.text != cell.text { cell.query.text = cell.text }
        }
    }

    private func nerdgraphEditor(variables: Bool) -> some View {
        let source = NerdgraphCellSource(editorText: liveText)
        let text = variables ? source.variables : source.query
        let service = variables ? variablesService : graphqlService
        return CodeEditor(
            text: Binding(get: {
                let source = NerdgraphCellSource(editorText: liveText)
                return variables ? source.variables : source.query
            }, set: { value in
                var source = NerdgraphCellSource(editorText: liveText)
                if variables {
                    source.variables = value
                    source.hasVariables = true
                } else {
                    source.query = value
                }
                draft = source.editorText
                cell.query.text = source.storedText
            }),
            position: variables ? $variablesPosition : $position,
            messages: $messages,
            language: variables ? .graphqlVariables(service) : .graphql(service)
        )
        .onAppear {
            CompletionKeyRouter.installIfNeeded()
            service.setTextSource {
                let source = NerdgraphCellSource(editorText: draft ?? cell.editorText)
                return variables ? source.variables : source.query
            }
            service.setScopeSource(completionScope)
            service.setConnectionSource(connectionSource)
            if !variables { service.setCompletionErrorHandler { graphqlCompletionError = $0 } }
        }
        .environment(\.codeEditorSetActions, CodeEditor.SetActions { service.setCompletionAction($0.completions) })
        .environment(\.codeEditorLayoutConfiguration, CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: true))
        .environment(\.codeEditorTheme, colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)
        .frame(height: CGFloat(max(text.components(separatedBy: "\n").count, 3)) * 18 + 16)
        .background(EditorFocusAnchor(focusRequested: !variables && cell.focusOnAppear) { cell.focusOnAppear = false })
        .onChange(of: variables ? variablesPosition : position) { onFocus() }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func insertGraphqlField(_ name: String) {
        var source = NerdgraphCellSource(editorText: liveText)
        let text = source.query as NSString
        let selection = position.selections.first ?? NSRange(location: text.length, length: 0)
        guard selection.location != NSNotFound, NSMaxRange(selection) <= text.length else {
            graphqlCompletionError = "Place the cursor in the GraphQL editor before inserting a field."
            return
        }
        source.query = text.replacingCharacters(in: selection, with: name)
        draft = source.editorText
        cell.query.text = source.storedText
        position = .init(selections: [NSRange(location: selection.location + name.utf16.count, length: 0)], verticalScrollPosition: position.verticalScrollPosition)
        cell.focusOnAppear = true
        onFocus()
    }

    private var renderedMarkdown: some View {
        Group {
            if cell.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Empty Markdown cell. Click to edit.").foregroundStyle(.secondary)
            } else {
                MarkdownView(text: cell.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            cell.focusOnAppear = true
            onFocus()
        }
    }

    private var editor: some View {
        CodeEditor(
            text: Binding(get: { liveText }, set: {
                draft = $0
                // Execution must see routing edits immediately, even before the document's debounce.
                cell.query.text = cell.kind.wrap($0)
            }),
            position: $position,
            messages: $messages,
            language: cell.kind == .nrql ? .nrql(languageService)
                : cell.kind == .lua ? .lua(luaService)
                : cell.kind == .config ? .nrql(configService) : .none
        )
        .onAppear {
            CompletionKeyRouter.installIfNeeded()
            for service in [languageService, luaService, configService] {
                service.setTextSource { draft ?? cell.editorText }
                service.setScopeSource(completionScope)
                service.setConnectionSource(connectionSource)
            }
        }
        .environment(\.codeEditorSetActions, CodeEditor.SetActions {
            languageService.setCompletionAction($0.completions)
            luaService.setCompletionAction($0.completions)
            configService.setCompletionAction($0.completions)
        })
        .environment(\.codeEditorLayoutConfiguration, CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: true))
        .environment(\.codeEditorTheme, (colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight))
        .frame(height: editorHeight)
        .background(EditorFocusAnchor(focusRequested: cell.focusOnAppear) { cell.focusOnAppear = false })
        .onAppear {
            // a new cell starts with the cursor after its template
            if cell.focusOnAppear {
                let end = (cell.editorText as NSString).length
                position = .init(selections: [NSMakeRange(end, 0)], verticalScrollPosition: 0)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onChange(of: position) { onFocus() }
        .task(id: draft) {
            guard let pending = draft, pending != cell.editorText else { return }
            try? await Task.sleep(for: .milliseconds(300))
            if !Task.isCancelled { cell.editorText = pending }
        }
        .onDisappear {
            // the editor goes away when a Markdown cell loses focus, possibly before the pause ends
            if let pending = draft, pending != cell.editorText { cell.editorText = pending }
            draft = nil
        }
        .onChange(of: cell.text) {
            if let draft, draft != cell.editorText { self.draft = nil }
            // undo/redo of the document restores whole cells without running the text observer
            if cell.query.text != cell.text { cell.query.text = cell.text }
        }
    }

    private var header: some View {
        HStack {
            if cell.kind == .config {
                collapseButton
                Text("Document Config").font(.headline)
                Spacer()
                actionsMenu
            } else if cell.kind == .markdown {
                if !isRenderedMarkdown {
                    Text("Markdown").font(.headline)
                }
                Spacer()
                actionsMenu
            } else {
                codeHeader
            }
        }
    }

    private var collapseButton: some View {
        let title = cell.kind == .config
            ? (cell.isCollapsed ? "Show config" : "Hide config")
            : (cell.isCollapsed ? "Show query" : "Hide query")
        return Button(title, systemImage: cell.isCollapsed ? "chevron.right" : "chevron.down") {
            cell.isCollapsed.toggle()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    private var codeHeader: some View {
        HStack {
            collapseButton

            Text(cell.query.title)
                .font(.headline)
            Spacer()

            if let sent = cell.kind == .nerdgraph ? cell.query.executedVariables : cell.query.executedNrql {
                Button(cell.kind == .nerdgraph ? "Variables Sent" : "Query Sent", systemImage: "text.alignleft") {
                    showsSentQuery.toggle()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help(cell.kind == .nerdgraph ? "Show the interpolated variables that were sent" : "Show the query that was sent")
                .popover(isPresented: $showsSentQuery) {
                    Text(sent)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 480, alignment: .leading)
                        .padding()
                }
            }

            if cell.kind != .nerdgraph {
                Button("Chart Settings", systemImage: "gearshape") {
                    showsChartSettings.toggle()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(showsChartSettings ? Color.accentColor : Color.primary)
            } else {
                Button("Browse GraphQL Fields", systemImage: "sidebar.left") {
                    showsGraphqlSchema.toggle()
                    cell.isCollapsed = false
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(showsGraphqlSchema ? Color.accentColor : Color.primary)
                .help("Find schema fields, read documentation, and insert a field")
            }

            if !warnings.isEmpty {
                Button("Warnings", systemImage: "exclamationmark.triangle.fill") {
                    showsWarnings.toggle()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.yellow)
                .help(warnings.joined(separator: "\n"))
                .popover(isPresented: $showsWarnings) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(warnings, id: \.self) { Text($0) }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 320, alignment: .leading)
                    .padding()
                }
            }

            Button("Run", systemImage: "play.fill") {
                onFocus()
                onRun()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(!cell.isRunnable || cell.query.isRunning)

            actionsMenu
        }
    }

    private var actionsMenu: some View {
        Menu("Cell Actions", systemImage: "ellipsis") {
            Menu("Add Above") {
                ForEach(NrqlCellKind.allCases.filter { $0 != .config }) { kind in
                    Button(kind.title) { onAction(.add(kind, above: true)) }
                }
            }
            Menu("Add Below") {
                ForEach(NrqlCellKind.allCases.filter { $0 != .config }) { kind in
                    Button(kind.title) { onAction(.add(kind, above: false)) }
                }
            }
            Menu("Convert To") {
                ForEach(NrqlCellKind.allCases.filter { $0 != .config }) { kind in
                    Button(kind.title) { onAction(.convert(kind)) }
                        .disabled(!canPerform(.convert(kind)))
                }
            }
            Divider()
            Button("Move Up") { onAction(.moveUp) }
                .disabled(!canPerform(.moveUp))
            Button("Move Down") { onAction(.moveDown) }
                .disabled(!canPerform(.moveDown))
            Divider()
            Button("Delete", role: .destructive) { onAction(.delete) }
        }
        .labelStyle(.iconOnly)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

struct CellResultView: View {
    let query: NrqlQuery
    @Binding var configurationShowing: Bool

    var body: some View {
        content
    }

    @ViewBuilder private var content: some View {
        switch query.state {
        case .idle:
            EmptyView()
        case .running:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 80)
        case .loaded(let container):
            if query.format?.hidesChart == true {
                Text("\(container.data.count) rows (chart hidden)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ConfigurableChartView(resultsContainer: container, format: query.format, configurationShowing: $configurationShowing)
                    // rebuild when the format comment changes, so it applies as you type
                    .id(query.format)
                    .frame(maxWidth: .infinity, minHeight: 300)
            }
        case .jsonLoaded(let value):
            JSONResultView(value: value)
        case .failed(let message):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text("The query failed")
                        .font(.headline)
                    Text(message)
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    DocumentView(document: .constant(NRQL_EditorDocument()))
}
