//
//  NrqlQuery.swift
//  NR Status
//
//  Created by Eric Baur on 10/14/24.
//

import Foundation
import CryptoKit

class NrqlQuery : Identifiable, ObservableObject {
    // this is the full text, including comments
    var text: String = "" {
        willSet { textWillUpdate(to: newValue) }
    }
    
    // this is just the functional part, minus comments
    var nrql: String {
        willSet {
            self.invalidated = true
        }
    }
    
    // we set this when the query changes
    var invalidated: Bool = false
    
    // the data behind the NRQL, but not trustworthy if invalidated == true
    // this attribute should work with observableobject, but I'm not sure it's working as I expected
    @Published var resultContainer: NrdbResultContainer?
    
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
        textWillUpdate(to: text)
        
        if run {
            self.runQuery()
        }
    }
    
    func getData() async {
        self.resultContainer = await Queries().getNrqlData(query: nrql, debug: false)
    }
    
    func runQuery(_ callback: ((NrdbResultContainer?) -> ())? = nil) {
        Queries().nrql(query: nrql) {
            self.resultContainer = $0
            self.invalidated = false
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

