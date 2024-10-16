//
//  NrqlQuery.swift
//  NR Status
//
//  Created by Eric Baur on 10/14/24.
//

import Foundation

struct NrqlQuery : Identifiable {
    var id: String = UUID().uuidString
    
    var title: String = "NRQL Query"
    var nrql: String
    
//    var _resultContainer: NrdbResultContainer?
//    var resultContainer: NrdbResultContainer {
//        guard _resultContainer == nil else { return _resultContainer! }
//        self._resultContainer = Queries().getNrqlData(query: nrql, debug: false)
//        return _resultContainer!
//    }
}
