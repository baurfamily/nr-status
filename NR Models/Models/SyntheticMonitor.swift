//
//  SyntheticMonitor.swift
//  NR Status
//
//  Created by Eric Baur on 9/26/24.
//

struct SyntheticMonitor {
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
    
    static func all() -> [SyntheticMonitor] {
        var apps: [SyntheticMonitor] = []
        Queries.entities(domain: .APM) { applications in
            if let applications = applications {
                apps = applications.map { Self(entity: $0) }
            }
        }
        return apps
    }
}
