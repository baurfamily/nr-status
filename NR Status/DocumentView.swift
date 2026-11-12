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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach($document.cells) { $cell in
                    CellView(
                        cell: $cell,
                        isFocused: document.focusedCellId == cell.id,
                        onFocus: { document.focusedCellId = cell.id },
                        onRun: { document.runCell(cell.id) },
                        pendingTitles: document.pendingDependencies(for: cell.id).map(\.query.title),
                        onDelete: { document.removeCell(cell.id) }
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
    let onFocus: () -> Void
    let onRun: () -> Void
    let pendingTitles: [String]
    let onDelete: () -> Void

    @State private var position: CodeEditor.Position = .init(selections: [NSMakeRange(0, 0)], verticalScrollPosition: 0)
    @State private var messages: Set<TextLocated<Message>> = Set()
    @State private var languageService = NrqlLanguageService()
    // the chart settings inspector is hidden until asked for
    @State private var showsChartSettings = false
    @State private var showsSentQuery = false


    // the editor scrolls itself, so give it room for the lines it has
    private var editorHeight: CGFloat {
        CGFloat(max(cell.text.split(separator: "\n", omittingEmptySubsequences: false).count, 2)) * 18 + 16
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            CodeEditor(
                text: $cell.text,
                position: $position,
                messages: $messages,
                language: cell.query.isScript ? .none : .nrql(languageService)
            )
            .onAppear {
                CompletionKeyRouter.installIfNeeded()
                languageService.setTextSource { cell.text }
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

            if !pendingTitles.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help("Running this cell will also run: \(pendingTitles.joined(separator: ", "))")
            }

            Button("Run", systemImage: "play.fill") {
                onFocus()
                onRun()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(!cell.isRunnable || cell.query.isRunning)

            Button("Delete", systemImage: "trash", action: onDelete)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
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
