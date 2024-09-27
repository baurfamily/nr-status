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
        case guid, accountId, name, domain, entityDomainAndType = "entityType", entityTypename = "type", alertSeverity, reporting
    }
    
    enum Domain : String, Codable {
        case APM, BROWSER, EXT, INFRA, MOBILE, SYNTH, NR1
    }
    
    // turns out, this is only for searching, not returns
    enum SearchBuilderEntityType : String, Codable {
        case APPLICATION, MONITOR, DASHBOARD, HOST, WORKLOAD
    }

    enum EntityDomainAndType : String, Codable {
       case APM_APPLICATION_ENTITY,
        APM_DATABASE_INSTANCE_ENTITY,
        APM_EXTERNAL_SERVICE_ENTITY,
        BROWSER_APPLICATION_ENTITY,
        DASHBOARD_ENTITY,
        EXTERNAL_ENTITY,
        GENERIC_ENTITY,
        GENERIC_INFRASTRUCTURE_ENTITY,
        INFRASTRUCTURE_AWS_LAMBDA_FUNCTION_ENTITY,
        INFRASTRUCTURE_HOST_ENTITY,
        KEY_TRANSACTION_ENTITY,
        MOBILE_APPLICATION_ENTITY,
        SECURE_CREDENTIAL_ENTITY,
        SYNTHETIC_MONITOR_ENTITY,
        TEAM_ENTITY,
        THIRD_PARTY_SERVICE_ENTITY,
        UNAVAILABLE_ENTITY,
        WORKLOAD_ENTITY
    }

    
    var guid: String?
    var domain: Domain?
    var entityTypename: String?
    var entityDomainAndType: EntityDomainAndType?
    var accountId: Int?
    var name: String?
    var alertSeverity: AlertSeverity?
    var reporting: Bool?
    // not implemented yet
    // var summaryMetrics: SummaryMetrics
}
