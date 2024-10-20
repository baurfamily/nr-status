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
    static var exampleText: UTType {
        UTType(importedAs: "com.example.plain-text")
    }
}

struct DocumentQuery : Identifiable {
    var position: CodeEditor.Position
    // not sure if this attirbute accomplishes anything
    @ObservedObject var query: NrqlQuery
    var focused: Bool = false
    
    var startCharacter: Int {
        if let position = position.selections.first {
            return position.lowerBound
        } else {
            return 0
        }
    }
    
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
            for var query in queries { query.focused ? query.focused = false : nil }
            guard var docQuery = queryAt(newValue) else { return }
            docQuery.focused = true
            focusedQueryId = docQuery.id
        }
    }
//    var results: [Int:NrdbResultContainer] = [:]
    var focusedResult: NrdbResultContainer?
    var focusedQueryId: String?
    
    var messages: Set<TextLocated<Message>> = Set()
    
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
                    let query = NrqlQuery(from: queryLines.joined(separator: "\n"))
                    
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
            } else if let oldQuery = queries.first( where: { $0.query.id == newQuery.query.id } ) {
                // the query is the same, but the title might have changed
                // not sure if this will get weird if you have two idential queries in the editor???
                // really, the position check above might work for the vast majority of cases
                oldQuery.query.text = newQuery.query.text
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
        guard let docQuery = queries.first( where:{ NSLocationInRange(range.lowerBound, $0.position.selections.first!) }) else { return nil }
        
        return docQuery
    }
    
    mutating func runQuery() {
        guard let range = position.selections.first else { return }
        guard let docQuery = queries.first( where:{ NSLocationInRange(range.lowerBound, $0.position.selections.first!) }) else { return }
        
        docQuery.query.runQuery()
        self.position = .init(selections: [NSMakeRange(0, 0)], verticalScrollPosition: 0)
//        self.position = docQuery.position
        print("message!")
        self.messages.insert(
            TextLocated(
                location: TextLocation(oneBasedLine: 1, column: 1),
                entity: Message.init(category: .informational, length: 10, summary: "foobar baz", description: "more text here that can be long and formatted")
                )
            )

    }
    
    func getData(_ callback: @escaping (NrdbResultContainer?) -> Void) {
        queryAt(position)?.query.runQuery() { result in
                callback(result)
        }
        
    }
}
