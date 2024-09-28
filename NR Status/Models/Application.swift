//
//  Application.swift
//  NR Status
//
//  Created by Eric Baur on 9/26/24.
//

struct Application {
    @EnvironmentObject var queries: Queries
    
    let entity: Entity
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
    
    static func all() -> [Application] {
        var apps: [Application] = []
        Queries.entities(domain: .APM, debug: true) { applications in
            if let applications = applications {
                apps = applications.map { Self(entity: $0) }
            }
        }
        return apps
    }
    
   
    static func entities(domain: Entity.Domain, debug: Bool = false, _ callback: @escaping ([Entity]?) -> Void) {
        let query = """
             query NRStatus_EntitySearch(
                $cursor: String = null,
                $nral: String
             ){
               actor {
                 entitySearch(query: $nrql, options: {limit: 500}) {
                   results(cursor: $cursor) { 
                     entities {
                       ...EntityInfo
                       ...EntityFragmentExtension
                       guid
                     }
                     nextCursor
                   }
                   count
                 }
               }
             }

             fragment EntityInfo on EntityOutline {
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
           }
        
        """
        
        let variables : [String:Any]  = [
            "sortType": ["REPORTING","ALERT_SEVERITY","NAME"],
            "nrql": "(alertable IS TRUE AND accountId IN ( \(accountIds) ) AND domain = '\(domain.rawValue)')"
        ]
        
        NerdgraphClient(host: host, apiKey: apiKey).query(query, variables: variables, debug: debug) { result in
            callback(result.data?.actor?.entitySearch?.results?.entities)
        }
    }
}
