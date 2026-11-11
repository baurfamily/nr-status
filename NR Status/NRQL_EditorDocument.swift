//
//  NRQL_EditorDocument.swift
//  NRQL Editor
//
//  Created by Eric Baur on 10/14/24.
//

import SwiftUI
import UniformTypeIdentifiers
import CodeEditorView
import LanguageSupport

extension UTType {
    static var nrql: UTType {
        UTType(exportedAs: "net.baurhome.nrql")
    }
}

struct DocumentQuery : Identifiable {
    var position: CodeEditor.Position
    let query: NrqlQuery
    
    var startCharacter: Int {
        if let position = position.selections.first {
            return position.lowerBound
        } else {
            return 0
        }
    }
    
    // the resolved/unresolved suffix gives the results tab a new identity once data arrives
    var id: String { "\(position.selections.first?.upperBound ?? 0)-\(query.resultContainer == nil ? "nil" : "resolved")" }
    
    init(position: CodeEditor.Position, query: NrqlQuery) {
        self.position = position
        self.query = query
    }
}

struct NRQL_EditorDocument: FileDocument {
    var text: String {
        didSet {
            parseQueries()
        }
    }
    var position: CodeEditor.Position = .init(selections: [NSMakeRange(0, 0)], verticalScrollPosition: 0) {
        willSet {
            if let docQuery = queryAt(newValue) {
                focusedQueryId = docQuery.id
            }
        }
    }
    var focusedQueryId: String?
    
    var messages: Set<TextLocated<Message>> = Set()
    
    var queries: [DocumentQuery] = []

    init(text: String = "// Title of query\nSELECT count(*) FROM Transactions FACET name SINCE 1 day ago TIMESERIES 15 minutes") {
        self.text = text
        parseQueries()
    }

    static var readableContentTypes: [UTType] { [.nrql] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
            let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
        parseQueries()
    }
    
    mutating func parseQueries() {
        let potentialQueries = NrqlDocumentParser.parse(text).map { parsed in
            DocumentQuery(
                position: CodeEditor.Position(
                    selections: [parsed.range],
                    verticalScrollPosition: Double(parsed.range.location) // I have no idea if we can get this here
                ),
                query: NrqlQuery(from: parsed.text)
            )
        }
        
        // this is basically just merging the arrays
        // since an old query might have a resolved chart, we want to leave that around
        // so we prefer to keep the old one as long as the query is the same
        var newQueries: [DocumentQuery] = []
        for newQuery in potentialQueries {
            if var oldQuery = queries.first( where: { abs($0.startCharacter - newQuery.startCharacter) <= 1 }) {
                // the query may have changed, but it's in the same basic locaiton in the file
                // this update may be a no-op, if it changes the query then the chart will be invalidated
                oldQuery.query.text = newQuery.query.text
                oldQuery.position = newQuery.position
                newQueries.append(oldQuery)
            } else if var oldQuery = queries.first( where: { $0.query.id == newQuery.query.id } ) {
                // the query is the same, but the title or location might have changed
                // not sure if this will get weird if you have two idential queries in the editor???
                // really, the position check above might work for the vast majority of cases
                oldQuery.query.text = newQuery.query.text
                oldQuery.position = newQuery.position
                newQueries.append(oldQuery)
            } else {
                newQueries.append(newQuery)
            }
        }
        
        queries = newQueries
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
    
    func queryAt(_ position: CodeEditor.Position) -> DocumentQuery? {
        guard let range = position.selections.first else { return nil }
        return queries.first { query in
            guard let queryRange = query.position.selections.first else { return false }
            return NSLocationInRange(range.lowerBound, queryRange)
        }
    }
    
    // the query under the cursor
    var focusedQuery: DocumentQuery? { queryAt(position) }
    
    // queries are reference types, so this doesn't change the document itself
    func runFocusedQuery() {
        focusedQuery?.query.run()
    }
}
