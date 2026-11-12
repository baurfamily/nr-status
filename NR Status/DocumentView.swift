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
                        onDelete: { document.removeCell(cell.id) }
                    )
                }
                Button("Add Query", systemImage: "plus") {
                    document.addCell(after: document.cells.last?.id)
                }
                .buttonStyle(.borderless)
            }
            .padding()
        }
    }
}

struct CellView: View {
    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    @Binding var cell: NrqlCell
    let isFocused: Bool
    let onFocus: () -> Void
    let onDelete: () -> Void

    @State private var position: CodeEditor.Position = .init(selections: [NSMakeRange(0, 0)], verticalScrollPosition: 0)
    @State private var messages: Set<TextLocated<Message>> = Set()
    @State private var languageService = NrqlLanguageService()


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
                language: .nrql(languageService)
            )
            .onAppear { languageService.setTextSource { cell.text } }
            .environment(\.codeEditorLayoutConfiguration, CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: true))
            .environment(\.codeEditorTheme, (colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight))
            .frame(height: editorHeight)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onChange(of: position) { onFocus() }

            if !cell.isCollapsed {
                CellResultView(query: cell.query)
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

            Button("Run", systemImage: "play.fill") {
                onFocus()
                cell.query.run()
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

    var body: some View {
        switch query.state {
        case .idle:
            EmptyView()
        case .running:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 80)
        case .loaded(let container):
            ConfigurableChartView(resultsContainer: container, format: query.format)
                // rebuild when the format comment changes, so it applies as you type
                .id(query.format)
                .frame(maxWidth: .infinity, minHeight: 300)
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
