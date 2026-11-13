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

    var body: some View {
        let stale = document.staleCellIds
        let readingBelow = document.readingBelowCellIds
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach($document.cells) { $cell in
                    CellView(
                        cell: $cell,
                        isFocused: document.focusedCellId == cell.id,
                        isStale: stale.contains(cell.id),
                        readsFromBelow: readingBelow.contains(cell.id),
                        onFocus: { document.focusedCellId = cell.id },
                        onRun: { document.runCell(cell.id) },
                        pendingTitles: document.pendingDependencies(for: cell.id).map(\.query.title),
                        canPerform: { document.canPerform($0, on: cell.id) },
                        onAction: { document.perform($0, on: cell.id) }
                    )
                }
                HStack {
                    Button("Add Query", systemImage: "plus") {
                        document.addCell(after: document.cells.last?.id)
                    }
                    Button("Add Script", systemImage: "curlybraces") {
                        document.addCell(after: document.cells.last?.id, script: true)
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding()
        }
        .toolbar {
            ToolbarItem {
                Button("Run All", systemImage: "play.fill") { document.runAllQueries() }
                    .help("Run every query in this document")
                    .disabled(!document.cells.contains { $0.isRunnable })
            }
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
    let onRun: () -> Void
    let pendingTitles: [String]
    let canPerform: (NRQL_EditorDocument.CellAction) -> Bool
    let onAction: (NRQL_EditorDocument.CellAction) -> Void

    @State private var position: CodeEditor.Position = .init(selections: [NSMakeRange(0, 0)], verticalScrollPosition: 0)
    @State private var messages: Set<TextLocated<Message>> = Set()
    @State private var languageService = NrqlLanguageService()
    // the chart settings inspector is hidden until asked for
    @State private var showsChartSettings = false
    @State private var showsSentQuery = false
    @State private var showsWarnings = false
    // what the editor shows while typing; copied into the document after a pause so each
    // keystroke doesn't refresh the editor (which would break its undo coalescing)
    @State private var draft: String?

    private var liveText: String { draft ?? cell.text }

    private var warnings: [String] {
        var messages: [String] = []
        if isStale {
            messages.append("Out of date: a cell this one reads has run since. Run this cell to refresh it.")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            CodeEditor(
                text: Binding(get: { liveText }, set: { draft = $0 }),
                position: $position,
                messages: $messages,
                language: cell.query.isScript ? .none : .nrql(languageService)
            )
            .onAppear {
                CompletionKeyRouter.installIfNeeded()
                languageService.setTextSource { draft ?? cell.text }
            }
            .environment(\.codeEditorSetActions, CodeEditor.SetActions { languageService.setCompletionAction($0.completions) })
            .environment(\.codeEditorLayoutConfiguration, CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: true))
            .environment(\.codeEditorTheme, (colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight))
            .frame(height: editorHeight)
            .background(EditorFocusAnchor(focusRequested: cell.focusOnAppear) { cell.focusOnAppear = false })
            .onAppear {
                // a new cell starts with the cursor after its template; a script's goes inside the fence
                if cell.focusOnAppear {
                    let end = (cell.text as NSString).length - (cell.query.isScript ? 4 : 0)
                    position = .init(selections: [NSMakeRange(end, 0)], verticalScrollPosition: 0)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onChange(of: position) { onFocus() }
            .task(id: draft) {
                guard let pending = draft, pending != cell.text else { return }
                try? await Task.sleep(for: .milliseconds(300))
                if !Task.isCancelled { cell.text = pending }
            }
            .onChange(of: cell.text) {
                if let draft, draft != cell.text { self.draft = nil }
                // undo/redo of the document restores whole cells without running the text observer
                if cell.query.text != cell.text { cell.query.text = cell.text }
            }

            if !cell.isCollapsed {
                CellResultView(query: cell.query, configurationShowing: $showsChartSettings)
            }
        }
        .padding(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isFocused ? 2 : 1)
        )
    }

    private var header: some View {
        HStack {
            Button(cell.isCollapsed ? "Expand results" : "Collapse results",
                   systemImage: cell.isCollapsed ? "chevron.right" : "chevron.down") {
                cell.isCollapsed.toggle()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)

            Text(cell.query.title)
                .font(.headline)
            Spacer()

            if let sent = cell.query.executedNrql {
                Button("Query Sent", systemImage: "text.alignleft") {
                    showsSentQuery.toggle()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Show the query that was sent")
                .popover(isPresented: $showsSentQuery) {
                    Text(sent)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 480, alignment: .leading)
                        .padding()
                }
            }

            Button("Chart Settings", systemImage: "gearshape") {
                showsChartSettings.toggle()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(showsChartSettings ? Color.accentColor : Color.primary)

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

            Menu("Cell Actions", systemImage: "ellipsis") {
                Button("Add Query Above") { onAction(.addQueryAbove) }
                Button("Add Query Below") { onAction(.addQueryBelow) }
                Button("Add Script Above") { onAction(.addScriptAbove) }
                Button("Add Script Below") { onAction(.addScriptBelow) }
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
        case .failed(let message):
            VStack(alignment: .leading) {
                Text("The query failed")
                    .font(.headline)
                Text(message)
            }
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    DocumentView(document: .constant(NRQL_EditorDocument()))
}
