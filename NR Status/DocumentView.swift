//
//  DocumentView.swift
//  NRQL Editor
//
//  Created by Eric Baur on 10/14/24.
//

import SwiftUI
import CodeEditorView
import LanguageSupport
import WidgetKit

/// A notebook-style document: each query is a cell with its results below it.
struct DocumentView: View {
    @Binding var document: NRQL_EditorDocument
    @Environment(\.undoManager) private var undoManager
    var sourceName: String = "Untitled.nrmd"
    var sourceURL: URL? = nil
    @AppStorage("nerdgraphProfiles", store: NerdgraphConfig.sharedDefaults) private var profileSettingsData = Data()
    @State private var profileSettings = NerdgraphProfiles.Settings()
    @State private var configurationError: String?
    @State private var cellRevealRequest = UUID()
    @State private var publishing: PublicationSheet?
    @State private var aiTarget: AIAssist.Target?
    @State private var aiInsertedCellID: NrqlCell.ID?
    @State private var publishedIDs: Set<UUID> = []
    @State private var isUnpublishingAll = false
    @State private var showsBindingsInspector = false
    @State private var bindingsInspectorWidth: CGFloat = 440
    private let widgetNavigation = WidgetSourceNavigation.shared

    private enum PublicationSheet: Identifiable {
        case cell(UUID), all
        var id: String {
            switch self {
            case .cell(let id): id.uuidString
            case .all: "all"
            }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            notebook
                .onChange(of: cellRevealRequest) {
                    if let id = document.focusedCellId {
                        withAnimation { proxy.scrollTo(id, anchor: .top) }
                    }
                }
                .onChange(of: aiInsertedCellID) {
                    if let id = aiInsertedCellID {
                        withAnimation { proxy.scrollTo(id, anchor: .top) }
                    }
                }
        }
        .background(InspectorWindowExpansion(
            isPresented: showsBindingsInspector, inspectorWidth: bindingsInspectorWidth + 1
        ).allowsHitTesting(false))
        .toolbar { documentToolbar }
        .inspector(isPresented: $showsBindingsInspector) {
            WorkbookBindingsView(document: document, profiles: profileSettings, onJumpToCell: { id in
                document.revealCell(id)
                cellRevealRequest = UUID()
            })
                .inspectorColumnWidth(min: 320, ideal: 440, max: 650)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    if width > 0 { bindingsInspectorWidth = width }
                }
        }
        .sheet(item: $publishing) { selection in
            switch selection {
            case .cell(let id):
                PublishWidgetSheet(document: $document, cellID: id, sourceName: sourceName, sourceURL: sourceURL)
            case .all:
                PublishWidgetSheet(document: $document, cellID: nil, sourceName: sourceName, sourceURL: sourceURL)
            }
        }
        .sheet(item: $aiTarget) { target in
            AIAssistSheet(document: $document, target: target) { response in
                aiInsertedCellID = try AIAssist.apply(response, to: $document, target: target, undoManager: undoManager)
            }
        }
        .onAppear { loadPublishedIDs() }
        .task(id: widgetNavigation.revealRequest?.id) {
            guard let request = widgetNavigation.revealRequest,
                  sourceURL?.standardizedFileURL == request.fileURL else { return }
            if document.revealWidget(request.widget.id) {
                cellRevealRequest = UUID()
            } else {
                await widgetNavigation.recover(
                    request.widget, title: "Published chart not found in source file",
                    detail: "The workbook opened, but this cell's saved widget identity is missing or duplicated. It may have been removed or not saved after publishing."
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: WidgetRegistry.didChangeNotification)) { _ in
            loadPublishedIDs()
        }
        .task(id: profileSettingsData) {
            do {
                profileSettings = try NerdgraphProfiles.shared.load()
            } catch {
                configurationError = error.localizedDescription
            }
        }
        .onChange(of: document.cells.map(\.id)) { previous, current in
            if let id = NerdgraphDocumentation.shared.source?.cursor.cellID,
               previous.contains(id), !current.contains(id) {
                NerdgraphDocumentation.shared.clear(cellID: id)
            }
        }
        .onDisappear {
            if let id = NerdgraphDocumentation.shared.source?.cursor.cellID,
               document.cells.contains(where: { $0.id == id }) {
                NerdgraphDocumentation.shared.clear(cellID: id)
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
        .confirmationDialog("Unpublish All Widgets?", isPresented: $isUnpublishingAll) {
            Button("Unpublish All Widgets", role: .destructive) { unpublishAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Unpublish every published cell in this workbook. Desktop widgets will stop displaying these cells until you republish them.")
        }
    }

    private var notebook: some View {
        let stale = document.staleCellIds(profiles: profileSettings)
        let readingBelow = document.readingBelowCellIds
        let canPublishAll = document.cells.contains(where: \.canPublishWidget)
        let hasPublishedWidgets = document.cells.contains { cell in
            cell.widgetID.map { publishedIDs.contains($0) } ?? false
        }
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
                        completionScope: {
                            var scope = document.completionScope(excluding: cell.id)
                            scope.revision += String(describing: profileSettings)
                            return scope
                        },
                        connectionSource: { document.connection },
                        onRun: { document.runCell(cell.id) },
                        onAssist: { aiTarget = AIAssist.Target(cellID: cell.id, originalText: cell.query.text) },
                        pendingTitles: document.pendingDependencies(for: cell.id, stale: stale).map(\.query.title),
                        canPerform: { document.canPerform($0, on: cell.id) },
                        onAction: { document.perform($0, on: cell.id) },
                        isPublished: cell.widgetID.map { publishedIDs.contains($0) } ?? false,
                        canPublishAll: canPublishAll,
                        hasPublishedWidgets: hasPublishedWidgets,
                        onPublish: { publishing = .cell(cell.id) },
                        onUnpublish: { unpublish(cell.id) },
                        onUpdatePublished: { updatePublished(cell.id) },
                        onPublishAll: { publishing = .all },
                        onUpdateAll: { updateAllPublished() },
                        onUnpublishAll: { isUnpublishingAll = true }
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

    private func loadPublishedIDs() {
        do {
            publishedIDs = Set(try WidgetRegistry.shared().widgets().map(\.id))
        } catch { configurationError = error.localizedDescription }
    }

    private func updatePublished(_ cellID: UUID) {
        do {
            try WorkbookWidgetPublishing.update(
                cellID: cellID, document: &document, sourceName: sourceName,
                sourceURL: sourceURL, registry: WidgetRegistry.shared()
            )
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetRegistry.widgetKind)
        } catch { configurationError = error.localizedDescription }
    }

    private func unpublish(_ cellID: UUID) {
        do {
            try WorkbookWidgetPublishing.unpublish(
                cellID: cellID, document: document, registry: WidgetRegistry.shared()
            )
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetRegistry.widgetKind)
        } catch { configurationError = error.localizedDescription }
    }

    private func updateAllPublished() {
        defer { WidgetCenter.shared.reloadTimelines(ofKind: WidgetRegistry.widgetKind) }
        do {
            try WorkbookWidgetPublishing.updateAll(
                document: &document, sourceName: sourceName, sourceURL: sourceURL, registry: WidgetRegistry.shared()
            )
        } catch { configurationError = error.localizedDescription }
    }

    private func unpublishAll() {
        defer { WidgetCenter.shared.reloadTimelines(ofKind: WidgetRegistry.widgetKind) }
        do {
            try WorkbookWidgetPublishing.unpublishAll(document: document, registry: WidgetRegistry.shared())
        } catch { configurationError = error.localizedDescription }
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
                    cellRevealRequest = UUID()
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
            Button("AI Assist", systemImage: "sparkles") {
                aiTarget = AIAssist.Target(isDocument: true)
            }
            .help("Help write a document with your configured AI command")
            .accessibilityIdentifier("ai-assist")
            Button("Bindings", systemImage: "curlybraces.square") { showsBindingsInspector.toggle() }
                .help("Inspect variable bindings throughout this workbook")
                .accessibilityIdentifier("show-workbook-bindings")
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
    @Environment(\.openWindow) private var openWindow

    @Binding var cell: NrqlCell
    let isFocused: Bool
    let isStale: Bool
    let readsFromBelow: Bool
    let onFocus: () -> Void
    let completionScope: () -> LuaCompletion.Scope
    let connectionSource: () -> Result<NrqlConnection, Error>
    let onRun: () -> Void
    let onAssist: () -> Void
    let pendingTitles: [String]
    let canPerform: (NRQL_EditorDocument.CellAction) -> Bool
    let onAction: (NRQL_EditorDocument.CellAction) -> Void
    let isPublished: Bool
    let canPublishAll: Bool
    let hasPublishedWidgets: Bool
    let onPublish: () -> Void
    let onUnpublish: () -> Void
    let onUpdatePublished: () -> Void
    let onPublishAll: () -> Void
    let onUpdateAll: () -> Void
    let onUnpublishAll: () -> Void

    @State private var position: CodeEditor.Position = .init(selections: [NSMakeRange(0, 0)], verticalScrollPosition: 0)
    @State private var messages: Set<TextLocated<Message>> = Set()
    @State private var languageService = NrqlLanguageService()
    @State private var luaService = NrqlLanguageService(language: .lua)
    @State private var configService = NrqlLanguageService(language: .config)
    @State private var graphqlService = NrqlLanguageService(language: .graphql)
    @State private var variablesService = NrqlLanguageService(language: .variables)
    @State private var variablesPosition: CodeEditor.Position = .init(selections: [NSMakeRange(0, 0)], verticalScrollPosition: 0)
    @State private var graphqlCompletionError: String?
    @State private var bindingNode: JSONNode?
    // One configuration panel spans the header, editors, and results.
    @State private var showsChartSettings = false
    @State private var showsSentQuery = false
    @State private var showsWarnings = false
    // what the editor shows while typing; copied into the document after a pause so each
    // keystroke doesn't refresh the editor (which would break its undo coalescing)
    @State private var draft: String?
    @State private var markdownText: String?
    @State private var markdownError: String?

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
        HStack(alignment: .top, spacing: 0) {
            cellContent.frame(maxWidth: .infinity)
            if showsChartSettings {
                CellConfigurationView(
                    cell: $cell, isPresented: $showsChartSettings, isPublished: isPublished,
                    onUpdatePublished: {
                        if let draft {
                            cell.editorText = draft
                            self.draft = nil
                        }
                        onUpdatePublished()
                    },
                    completionScope: completionScope
                )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .clipped()
        .sheet(item: $bindingNode) { node in
            AddResultBindingSheet(
                cell: $cell, node: node, existingNames: completionScope().names + cell.query.resultNames
            )
        }
        .onChange(of: cell.focusOnAppear, initial: true) {
            if cell.kind == .config && cell.focusOnAppear {
                showsChartSettings = true
                cell.focusOnAppear = false
            }
        }
        .onChange(of: cell.configurationText) {
            // Commit a pending code edit before configuration changes can replace it.
            if let draft {
                cell.editorText = draft
                self.draft = nil
            }
            if isFocused { followGraphqlDocumentation() }
        }
        .onChange(of: cell.isCollapsed) {
            if cell.kind == .config && cell.isCollapsed { showsChartSettings = false }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isRenderedMarkdown ? Color.clear : isFocused ? Color.accentColor : Color.secondary.opacity(0.3),
                    lineWidth: isFocused ? 2 : 1
                )
        )
    }

    private var cellContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if cell.kind == .nerdgraph {
                HStack(alignment: .top, spacing: 16) {
                    if !cell.isCollapsed {
                        nerdgraphEditors
                            .frame(maxWidth: .infinity)
                    }
                    if cell.query.showsResultPane {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(cell.query.format?.showsBindings == true ? "Bindings" : "JSON Results")
                                .font(.caption).foregroundStyle(.secondary)
                            CellResultView(query: cell.query, onAddBinding: {
                                bindingNode = $0
                                showsChartSettings = true
                            })
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else if cell.kind == .config && !cell.isCollapsed {
                DocumentConfigurationSummaryView(text: cell.configurationText)
            } else if isRenderedMarkdown {
                renderedMarkdown
            } else if cell.kind != .config && (!cell.isCollapsed || cell.kind == .markdown) {
                editor
            }

            if cell.kind == .nrql || cell.kind == .lua {
                CellResultView(query: cell.query, onHeightChange: { cell.setChartHeight($0) })
            }
        }
        .padding(8)
        .onChange(of: cell.kind) {
            draft = nil
            if cell.kind == .markdown { showsChartSettings = false }
            if cell.kind != .nerdgraph { NerdgraphDocumentation.shared.clear(cellID: cell.id) }
        }
        .onChange(of: isFocused) { if isFocused { followGraphqlDocumentation() } }
        .onChange(of: liveText) { if isFocused { followGraphqlDocumentation() } }
        .onChange(of: String(describing: connectionSource())) {
            if NerdgraphDocumentation.shared.source?.cursor.cellID == cell.id { followGraphqlDocumentation() }
        }
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
        .onChange(of: cell.text) { previous, _ in
            if let draft, cell.kind.unwrap(previous) != cell.editorText, draft != cell.editorText { self.draft = nil }
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
                cell.query.text = cell.storedText(forEditorText: source.editorText)
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
            service.setConnectionSource(cellConnection)
            if !variables { service.setCompletionErrorHandler { graphqlCompletionError = $0 } }
            if isFocused { followGraphqlDocumentation() }
        }
        .environment(\.codeEditorSetActions, CodeEditor.SetActions { service.setCompletionAction($0.completions) })
        .environment(\.codeEditorLayoutConfiguration, CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: true))
        .environment(\.codeEditorTheme, colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)
        .frame(height: CGFloat(max(text.components(separatedBy: "\n").count, 3)) * 18 + 16)
        .background(EditorFocusAnchor(focusRequested: !variables && cell.focusOnAppear, onRun: {
            onFocus()
            onRun()
        }) { cell.focusOnAppear = false })
        .onChange(of: variables ? variablesPosition : position) {
            onFocus()
            followGraphqlDocumentation()
        }
        .simultaneousGesture(TapGesture().onEnded {
            onFocus()
            followGraphqlDocumentation()
        })
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
        cell.query.text = cell.storedText(forEditorText: source.editorText)
        position = .init(selections: [NSRange(location: selection.location + name.utf16.count, length: 0)], verticalScrollPosition: position.verticalScrollPosition)
        cell.focusOnAppear = true
        onFocus()
    }

    private func followGraphqlDocumentation() {
        guard cell.kind == .nerdgraph else { return }
        let source = NerdgraphCellSource(editorText: liveText)
        NerdgraphDocumentation.shared.source = .init(
            cursor: .init(cellID: cell.id, text: source.query, location: position.selections.first?.location ?? 0),
            loadID: cell.id.uuidString + cell.configurationText + String(describing: connectionSource()),
            load: { try await graphqlService.graphqlSchema() },
            onInsert: insertGraphqlField
        )
    }

    private var renderedMarkdown: some View {
        let scope = completionScope()
        let text = liveText
        let interpolates = NrqlInterpolation.containsPlaceholders(text)
        return Group {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Empty Markdown cell. Click to edit.").foregroundStyle(.secondary)
            } else if let markdownError, interpolates {
                Text(markdownError).foregroundStyle(.red).textSelection(.enabled)
            } else if !interpolates {
                MarkdownView(text: text)
            } else if let markdownText {
                MarkdownView(text: markdownText)
            } else {
                ProgressView("Rendering Markdown...")
            }
        }
        .task(id: text + scope.revision + String(describing: connectionSource())) {
            markdownText = nil
            markdownError = nil
            guard interpolates else { return }
            do {
                let config = try connectionSource().get().effectiveConfiguration(profiles: NerdgraphProfiles.shared.load())
                let expanded = try await Task.detached {
                    try NrqlInterpolation.expand(text, results: scope.results, config: config)
                }.value
                guard !Task.isCancelled else { return }
                markdownText = expanded
            } catch {
                guard !Task.isCancelled else { return }
                markdownError = error.localizedDescription
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
                cell.query.text = cell.storedText(forEditorText: $0)
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
                service.setConnectionSource(cellConnection)
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
        .background(EditorFocusAnchor(focusRequested: cell.focusOnAppear, onRun: cell.isRunnable ? {
            onFocus()
            onRun()
        } : nil) { cell.focusOnAppear = false })
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
        .onChange(of: cell.text) { previous, _ in
            if let draft, cell.kind.unwrap(previous) != cell.editorText, draft != cell.editorText { self.draft = nil }
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
                aiAssistButton
                configurationButton
                actionsMenu
            } else if cell.kind == .markdown {
                if !isRenderedMarkdown {
                    Text("Markdown").font(.headline)
                }
                publicationBadge
                Spacer()
                aiAssistButton
                actionsMenu
            } else {
                codeHeader
            }
        }
    }

    @ViewBuilder private var publicationBadge: some View {
        if isPublished {
            Label("Published", systemImage: "checkmark.circle")
                .labelStyle(.titleAndIcon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
                .help("Published as a widget")
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
            publicationBadge
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

            aiAssistButton
            configurationButton
            if cell.kind == .nerdgraph {
                Button("Nerdgraph Documentation", systemImage: "questionmark.circle") {
                    onFocus()
                    followGraphqlDocumentation()
                    openWindow(id: "graphql-documentation")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Open Nerdgraph documentation for the current query position")
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

    private var aiAssistButton: some View {
        Button("Help Write or Improve Cell", systemImage: "sparkles") {
            if let draft {
                cell.editorText = draft
                self.draft = nil
            }
            onAssist()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help("Write or improve this cell with AI")
        .accessibilityIdentifier("cell-ai-assist")
    }

    private var configurationButton: some View {
        Button("Configure Cell", systemImage: "gearshape") {
            if let draft {
                cell.editorText = draft
                self.draft = nil
            }
            onFocus()
            withAnimation { showsChartSettings.toggle() }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .foregroundStyle(showsChartSettings ? Color.accentColor : Color.primary)
    }

    private func cellConnection() -> Result<NrqlConnection, Error> {
        Result { try NrqlConnection.parse(cell.configurationText).inheriting(connectionSource().get()) }
    }

    private var actionsMenu: some View {
        Menu("Cell Actions", systemImage: "ellipsis") {
            if cell.kind == .config {
                Button("Publish All Widgets...", action: onPublishAll)
                    .disabled(!canPublishAll)
                if hasPublishedWidgets {
                    Button("Update All Widgets", action: onUpdateAll)
                    Button("Unpublish All Widgets...", role: .destructive, action: onUnpublishAll)
                }
                Divider()
            }
            if cell.canPublishWidget {
                Button(isPublished ? "Update Published Widget..." : "Publish as Widget...", systemImage: "square.grid.2x2") {
                    if let draft {
                        cell.editorText = draft
                        self.draft = nil
                    }
                    onPublish()
                }
            }
            if isPublished {
                Button("Unpublish Widget", role: .destructive, action: onUnpublish)
            }
            if cell.canPublishWidget || isPublished {
                Divider()
            }
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
            Button("Duplicate Cell", systemImage: "doc.on.doc") { onAction(.duplicate) }
                .disabled(!canPerform(.duplicate))
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
    var onHeightChange: ((Int?) -> Void)?
    var onAddBinding: ((JSONNode) -> Void)?
    @State private var chartHeight: CGFloat = 300
    @State private var previewHeightInLines: Int?

    private var displayedFormat: ChartFormat {
        var format = query.format ?? ChartFormat()
        if let previewHeightInLines { format.heightInLines = previewHeightInLines }
        return format
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = query.errorMessage {
                Label(message, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red).textSelection(.enabled)
                if query.failedBindingResponse != nil {
                    Text("The response was received, but no bindings from this run are available to other cells. Fix the bindings and run again.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if query.format?.showsBindings == true, let value = query.jsonResult {
                BindingResultsView(bindings: query.inspectedBindings)
                ForEach(Array(value.graphQLErrors.enumerated()), id: \.offset) { _, message in
                    Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
            } else {
                content
            }
        }
    }

    @ViewBuilder private var content: some View {
        if let output = query.displayedConsole {
            ConsoleOutputView(lines: output)
                .padding(8)
                .background(.quaternary.opacity(0.5))
        } else if let json = query.displayedJSON {
            switch json {
            case .success(let value):
                JSONResultView(value: value, onAddBinding: onAddBinding)
            case .failure(let error):
                Text(error.localizedDescription).foregroundStyle(.red).textSelection(.enabled)
            }
        } else {
            resultContent
        }
    }

    @ViewBuilder private var resultContent: some View {
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
                VStack(spacing: 0) {
                    ConfigurableChartView(resultsContainer: container, format: displayedFormat)
                        .withoutConfiguration()
                        .documentSized()
                        .id(displayedFormat)
                        .frame(maxWidth: .infinity)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { chartHeight = $0 }
                    if onHeightChange != nil {
                        resizeHandle
                    }
                }
            }
        case .jsonLoaded(let value):
            ForEach(Array(value.graphQLErrors.enumerated()), id: \.offset) { _, message in
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        case .consoleLoaded:
            Text(query.format?.hidesChart == true
                 ? "Console output hidden"
                 : "No result data. Choose Console to view print output.")
                .font(.caption).foregroundStyle(.secondary)
        case .failed:
            EmptyView()
        }
    }

    private var resizeHandle: some View {
        ChartResizeHandle(
            height: chartHeight,
            onPreview: { previewHeightInLines = $0 },
            onCommit: {
                onHeightChange?($0)
                previewHeightInLines = nil
            }
        )
            .frame(height: 12)
    }
}

private struct ChartResizeHandle: NSViewRepresentable {
    let height: CGFloat
    let onPreview: (Int?) -> Void
    let onCommit: (Int?) -> Void

    func makeNSView(context: Context) -> HandleView {
        let view = HandleView()
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.splitter)
        view.setAccessibilityLabel("Chart height")
        view.setAccessibilityIdentifier("chart-height-resize-handle")
        view.setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: "Reset to Auto", handler: { [weak view] in
                view?.onCommit?(nil)
                return true
            })
        ])
        view.toolTip = "Drag to resize the chart in lines. Double-click to reset to Auto."
        return view
    }

    func updateNSView(_ view: HandleView, context: Context) {
        view.height = height
        view.onPreview = onPreview
        view.onCommit = onCommit
        view.setAccessibilityValue("\(ChartConfiguration.lines(forHeight: height)) lines")
    }

    final class HandleView: NSView {
        var height: CGFloat = 300
        var onPreview: ((Int?) -> Void)?
        var onCommit: ((Int?) -> Void)?
        private var startHeight: CGFloat?
        private var startY: CGFloat = 0
        private var didDrag = false

        override var acceptsFirstResponder: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .resizeUpDown)
        }

        override func draw(_ dirtyRect: NSRect) {
            (didDrag ? NSColor.controlAccentColor : NSColor.secondaryLabelColor).setFill()
            NSBezierPath(
                roundedRect: NSRect(x: bounds.midX - 16, y: bounds.midY - 1.5, width: 32, height: 3),
                xRadius: 1.5, yRadius: 1.5
            ).fill()
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            if event.clickCount == 2 {
                onCommit?(nil)
                return
            }
            startHeight = height
            startY = event.locationInWindow.y
            didDrag = false
        }

        override func mouseDragged(with event: NSEvent) {
            guard let startHeight else { return }
            didDrag = true
            onPreview?(ChartConfiguration.lines(forHeight: startHeight + startY - event.locationInWindow.y))
            needsDisplay = true
        }

        override func mouseUp(with event: NSEvent) {
            if let startHeight, didDrag {
                onCommit?(ChartConfiguration.lines(forHeight: startHeight + startY - event.locationInWindow.y))
            }
            startHeight = nil
            didDrag = false
            needsDisplay = true
        }

        override func cancelOperation(_ sender: Any?) {
            startHeight = nil
            didDrag = false
            onPreview?(nil)
            needsDisplay = true
        }

        override func accessibilityPerformIncrement() -> Bool {
            onCommit?(ChartConfiguration.lines(forHeight: height) + 1)
            return true
        }

        override func accessibilityPerformDecrement() -> Bool {
            onCommit?(max(1, ChartConfiguration.lines(forHeight: height) - 1))
            return true
        }
    }
}

#Preview {
    DocumentView(document: .constant(NRQL_EditorDocument()))
}
