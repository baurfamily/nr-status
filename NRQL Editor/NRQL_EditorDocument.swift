//
//  NRQL_EditorDocument.swift
//  NRQL Editor
//
//  Created by Eric Baur on 10/14/24.
//

import SwiftUI
import UniformTypeIdentifiers
import CodeEditorView

extension UTType {
    static var exampleText: UTType {
        UTType(importedAs: "com.example.plain-text")
    }
}

struct DocumentQuery : Identifiable {
    var position: CodeEditor.Position
    var query: NrqlQuery
    
    var id: String { query.id }
}

struct NRQL_EditorDocument: FileDocument {
    var text: String
    var position: CodeEditor.Position = .init(selections: [NSMakeRange(0, 0)], verticalScrollPosition: 0)
    var results: [String:NrdbResultContainer] = [:]
    
    var queries: [DocumentQuery] = []

    init(text: String = "// Title of query\nSELECT count(*) FROM Transactions FACET name SINCE 1 day ago TIMESERIES 15 minutes") {
        self.text = text
    }

    static var readableContentTypes: [UTType] { [.exampleText] }

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
        var potentialQueries: [DocumentQuery] = []
        
        var position = 0
        var commentStart = 0
        var queryStart = 0
        var queryLines: [String] = []
        for substr in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(substr)
            
            if line.isEmpty {
                if queryLines.count > 0 {
                    let position = CodeEditor.Position(
                        selections: [NSMakeRange( queryStart, position - queryStart )],
                        verticalScrollPosition: Double(queryStart) // I have no idea if we can get this here
                    )
                    let query = NrqlQuery(nrql: queryLines.joined(separator: "\n"))
                    
                    potentialQueries.append(
                        DocumentQuery( position: position, query: query )
                    )
                    commentStart = 0
                    queryStart = 0
                    queryLines.removeAll()
                }
            } else {
                if line.starts(with: "//") && commentStart == 0 {
                    commentStart = position
                }
                if !line.starts(with: "//") && queryStart == 0 {
                    queryStart = position
                }
                queryLines.append(line)
            }
            
            // increment out position based on the number of characters read
            position += substr.count + 1 // account for stripped newline
        }
        
        queries = potentialQueries
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
    
    mutating func runQuery() {
        print("running current query")
        print("at: \(position)")
        
        guard let range = position.selections.first else { return }
        guard let docQuery = queries.first( where:{ NSLocationInRange(range.lowerBound, $0.position.selections.first!) }) else { return }
        
        print("running query: \(docQuery.query.nrql)")
        docQuery.query.runQuery()
        position.selections = [range]
    }
}
