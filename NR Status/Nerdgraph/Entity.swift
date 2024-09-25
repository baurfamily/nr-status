//
//  Entity.swift
//  NR Status
//
//  Created by Eric Baur on 9/24/24.
//

//"accountId": 265881,
//              "alertSeverity": "NOT_CONFIGURED",
//              "domain": "APM",
//              "guid": "MjY1ODgxfEFQTXxBUFBMSUNBVElPTnwyOTk2Nzgy",
//              "name": "TaT (production)",
//              "reporting": true,
//              "summaryMetrics": null,
//              "type": "APPLICATION"


struct Entity : Codable {
    enum CodingKeys: String, CodingKey {
        case guid, accountId, name, domain //, type = "entityType"
    }
    
    enum Domain : String, Codable {
        case APM, BROWSER, EXT, INFRA, MOBILE, SYNTH
    }
    enum EntityType : String, Codable {
        case APPLICATION, MONITOR, DASHBOARD, HOST, WORKLOAD
    }
    
    var guid: String?
    var domain: Domain?
    var type: EntityType?
    var accountId: Int?
    var name: String?
    var alertSeverity: AlertSeverity?
    var reporting: Bool?
    // not implemented yet
    // var summaryMetrics: SummaryMetrics
}

