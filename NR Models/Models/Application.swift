//
//  Application.swift
//  NR Status
//
//  Created by Eric Baur on 9/26/24.
//

import Foundation

struct Application {
    // wrapped object
    let entity: Entity
    let index: Int

    // globals
    static var accountIds: String {
        return UserDefaults.standard.string(forKey: "accountIds") ?? ""
    }
    
    // default properties
    var name: String {
        guard let name = entity.name else { return "Unknown" }
        return name
    }
    var guid: String {
        guard let guid = entity.guid else { return "n/a" }
        return guid
    }
    var alertSeverity: AlertSeverity {
        guard let alertSeverity = entity.alertSeverity else { return .NOT_CONFIGURED }
        return alertSeverity
    }
    
    // collection
    static func all(_ callback: @escaping ([Application]) -> Void) {
        entities(domain: .INFRA, debug: false) { applications in
            if let applications = applications {
                let apps = applications.enumerated().map { (index, entity ) in
                    Self(entity: entity, index: index)
                }
                callback(apps)
            } else {
                callback([])
            }
        }
    }
    
    // nerdgraph query
    static func entities(domain: Entity.Domain, debug: Bool = false, _ callback: @escaping ([Entity]?) -> Void) {
        let query = """
             query NRStatus_EntitySearch(
                $nrql: String,
                $sortType: [EntitySearchSortCriteria] = null
             ){
               actor {
                 entitySearch(query: $nrql, sortBy: $sortType, options: {limit: 500}) {
                   results { 
                     entities {
                       guid
                       accountId
                       domain
                       type
                       name
                       reporting
                       account {
                         id
                         name
                       }
                       ... on AlertableEntityOutline {
                         alertSeverity
                       }
                     }
                     nextCursor
                   }
                   count
                 }
               }
             }
        """
        
        let variables : [String:Any]  = [
            "sortType": ["REPORTING","ALERT_SEVERITY","NAME"],
            "nrql": "(alertable IS TRUE AND accountId IN ( \(self.accountIds) ) AND domain = '\(domain.rawValue)')"
        ]
        
        NerdgraphClient().query(query, variables: variables, debug: debug) { result in
            callback(result.data?.actor?.entitySearch?.results?.entities)
        }
    }
}
