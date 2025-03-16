//
//  NrqlQuery.swift
//  NR Status
//
//  Created by Eric Baur on 10/14/24.
//

import Foundation
import CodeEditorView
import CryptoKit
import LanguageSupport

@Observable class NrqlQuery : Identifiable, Equatable {
    // this is the full text, including comments
    var text: String = "" {
        willSet { print("."); textWillUpdate(to: newValue) }
    }
    
    // this is just the functional part, minus comments
    var nrql: String {
        willSet {
            self.invalidated = true
        }
    }
    
    static func == (lhs: NrqlQuery, rhs: NrqlQuery) -> Bool {
        lhs.text == rhs.text
    }
    
    // so we can be embeded in a code editor, we need a position and messages... I guess?
    // not sure if I really need these, or if they need/should be here.
    var position: CodeEditor.Position
    var messages: Set<TextLocated<Message>> = Set()
    
    // we set this when the query changes
    var invalidated: Bool = false
    
    // set this when things get run; clear when completed
    var running: Bool = false
    
    // the data behind the NRQL, but not trustworthy if invalidated == true
    // this attribute should work with observableobject, but I'm not sure it's working as I expected
    var resultContainer: NrdbResultContainer?
    
    var id: String { hash(nrql: self.nrql) }
    
    var title: String {
        let defaultTitle = "NRQL Query"
        guard let titleString = text.split(separator: "\n").first else { return defaultTitle }
        guard titleString.starts(with: "//") else { return defaultTitle }
        
        let title = titleString.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return defaultTitle }
        
        return title
    }
    
    init(from text: String, run: Bool = false) {
        self.nrql = ""
        self.text = text
        self.position = .init(selections: [NSMakeRange(0, 0)], verticalScrollPosition: 0)
        self.messages = Set<TextLocated<Message>>()
        
        textWillUpdate(to: text)
        
        if run {
            self.runQuery()
        }
    }
    
    func getData() async {
        self.invalidated = true
        self.running = true
        //why do I have to do this?
        //...if I don't, the UI doesn't update (unless something went wrong with the query
        self.resultContainer = nil
        self.resultContainer = await Queries().getNrqlData(query: nrql, debug: false)
        self.invalidated = false
        self.running = false
    }
    
    func runQuery(_ callback: ((NrdbResultContainer?) -> ())? = nil) {
        self.invalidated = true
        self.running = true
        Queries().nrql(query: nrql) {
            self.resultContainer = $0
            self.invalidated = false
            self.running = false
            if let callback { callback($0) }
        }
    }
    
    private func hash(nrql: String) -> String {
        SHA256.hash( data:Data(nrql.utf8) ).description
    }
    
    private func textWillUpdate(to newValue: String) {
        var lines: [Substring] = []
        for line in newValue.split(separator: "\n") {
            guard !line.starts(with: "//") else { continue }
            lines.append(line)
        }
        let nrql = lines.joined(separator: "\n")
        if hash(nrql: nrql) != hash(nrql: self.nrql) {
            self.nrql = nrql
        }
    }
}

