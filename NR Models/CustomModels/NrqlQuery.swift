//
//  NrqlQuery.swift
//  NR Status
//
//  Created by Eric Baur on 10/14/24.
//

import Foundation
import CryptoKit



class NrqlQuery : Identifiable {
    var nrql: String {
        willSet {
            self.resultContainer = nil
        }
    }
    var resultContainer: NrdbResultContainer?
    
    var id: String {
        SHA256.hash( data:Data(self.nrql.utf8) ).description
    }
    
    var title: String {
        let defaultTitle = "NRQL Query"
        guard let titleString = nrql.split(separator: "\n").first else { return defaultTitle }
        guard titleString.starts(with: "//") else { return defaultTitle }
        
        let title = titleString.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return defaultTitle }
        
        return title
    }
    
    init(nrql: String, runQuery: Bool = false) {
        self.nrql = nrql
        if runQuery {
            self.runQuery()
        }
    }
    
    func getData() async {
        self.resultContainer = await Queries().getNrqlData(query: nrql, debug: false)
    }
    
    func runQuery() {
        Queries().nrql(query: nrql) { print("got results! \($0?.nrql)"); self.resultContainer = $0 }
    }
}

