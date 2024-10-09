//
//  Basic.swift
//  NR Status
//
//  Created by Eric Baur on 9/22/24.
//

import Foundation

struct Root : Codable {
    enum CodingKeys: CodingKey {
        case data
    }
    var data: Data?
}

struct Data : Codable {
    enum CodingKeys: CodingKey {
        case actor
    }
    var actor: Actor?
}

struct Actor : Codable {
    enum CodingKeys: CodingKey {
        case user, accounts, entitySearch, nrql
    }
    var user: User?
    var accounts: [Account]?
    var entitySearch: EntitySearch?
    var nrql: NrdbResultContainer?
}

struct NrdbResultContainer : Codable {
    enum CodingKeys: CodingKey {
        case results, nrql
    }
    var nrql: String?
    var results: [NrqlFacetResults] = []
}

struct NrqlFacetResults: Codable, Identifiable {
    enum CodingKeys: CodingKey {
        case beginTimeSeconds, count, endTimeSeconds, facet
    }

    var id: Int { beginTimeSeconds ?? 0 }
    
    var beginTime: Date { Date(timeIntervalSince1970: Double(beginTimeSeconds ?? 0)) }
    var endTime: Date { Date(timeIntervalSince1970: Double(endTimeSeconds ?? 0)) }
    
    var beginTimeSeconds: Int?
    var count: Int
    var endTimeSeconds: Int?
    var facet: String?
}


struct EntitySearch : Codable {
    enum CodingKeys: CodingKey {
        case count, results, types
    }
    var count: Int?
    var results: Results?
    var types: [EntityTypeGrouping]?
}

struct EntityTypeGrouping : Codable {
    enum CodingKeys: String, CodingKey {
        case count, domain, entityType = "type"
    }
    var count: Int?
    var domain: Entity.Domain?
    var entityType: String?
}

struct Results : Codable {
    enum CodingKeys : CodingKey {
        case nextCursor, entities
    }
    var nextCursor: String?
    var entities: [Entity]?
}

struct Account : Codable {
    enum CodingKeys: CodingKey {
        case id, name
    }
    var id: Int?
    var name: String?
}

struct User : Codable {
    enum CodingKeys: CodingKey {
        case email
    }
    var email: String?
}
