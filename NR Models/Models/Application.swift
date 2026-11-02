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
    static func all() async -> [Application] {
        let entities = (try? await Queries().entities(domain: .INFRA, detail: .basic)) ?? []
        return entities.enumerated().map { Self(entity: $1, index: $0) }
    }
}
