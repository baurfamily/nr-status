//
//  EditorMenuView.swift
//  NR Status
//
//  Created by Eric Baur on 10/15/24.
//

import SwiftUI

//here for testing
import CodeEditorView
import LanguageSupport

struct EditorMenuView : View {
    @FocusedBinding(\.document) var document: NRQL_EditorDocument?
    @FocusedBinding(\.query) var query: NrqlQuery?
    
    var body: some View {
        Group {
            Button("Run query...") {
                if var query {
                    print("query text: \(query.text)")
                    query.runQuery() { result in
                        // same issue noted below about ecapsulation
                        print("... got result back.")
                        query.resultContainer = result
                    }
                }
                if var document {
                    print("document text: \(document.text)")
                    document.runQuery() { result in
                        // ug, I don't like (breaks encapsulation), but I'm strugging to deal with an async
                        // callback that mutates the hosting struct... maybe my object architecture is just weird
                        print("... got result back.")
                        document.focusedResult = result
                    }
                    
                    document.messages.insert(
                        TextLocated(
                            location: TextLocation(oneBasedLine: 1, column: 1),
                            entity: Message.init(category: .informational, length: 10, summary: "foobar baz", description: "more text here that can be long and formatted")
                        )
                    )
                }
                // alternate method? seems to act the same
//                if var document {
//                    document.getData() {
//                        document.queryAt(document.position)?.query.resultContainer = $0
//                        document.focusedResult = $0
//                    }
//                }
            }.keyboardShortcut("\n")
        }
    }
}
