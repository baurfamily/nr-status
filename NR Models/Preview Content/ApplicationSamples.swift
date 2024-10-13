//
//  Application.swift
//  NR Status
//
//  Created by Eric Baur on 9/26/24.
//

extension Application {
    static func sample() -> Application {
        .init(entity: .init(
            guid: "1234567890",
            name: "Sample Application",
            alertSeverity: .NOT_CONFIGURED
        ), index: 0)
    }
    
    static func samples(count: Int) -> [Application] {
        let regions = [ "Background", "Prod.", "Production", "Staging", "Dev.", "Development", "EU", "US", "APAC", "MENA"]
        let nouns = [ "widget", "gadget", "build tool", "application", "service", "tool" ]
        let adjectives = [ "configurator", "user-site", "admin-site", "UI", "etl" ]
        
        return (0..<count).map { index in
                .init(entity: .init(
                    guid: "\(index)",
                    name: "\(regions.randomElement()!) \(nouns.randomElement()!) \(adjectives.randomElement()!)",
                    alertSeverity: AlertSeverity.allCases.randomElement()
                ), index: index)
        }
    }
}
