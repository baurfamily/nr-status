//
//  NRQL_EditorDocument.swift
//  NRQL Editor
//
//  Created by Eric Baur on 10/14/24.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var exampleText: UTType {
        UTType(importedAs: "com.example.plain-text")
    }
}

struct NRQL_EditorDocument: FileDocument {
    var text: String
    var queries: [NrqlQuery] {
        var queries: [NrqlQuery] = []
        
        var query = NrqlQuery(nrql:"")
        for substr in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(substr)
            
            if line.starts(with: "//") {
                query.title = String(line.dropFirst(2))
            } else if !line.isEmpty {
                query.nrql.append(line)
            } else {
                guard !query.nrql.isEmpty else { continue }
                queries.append(query)
                query = NrqlQuery(nrql:"")
            }
        }
        return queries
    }

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
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
    
    func runQuery() {
        print("running current query")
    }
}
