//
//  Basic.swift
//  NR Status
//
//  Created by Eric Baur on 9/22/24.
//

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
        case user, accounts, entitySearch
    }
    var user: User?
    var accounts: [Account]?
    var entitySearch: EntitySearch?
}

struct EntitySearch : Codable {
    enum CodingKeys: CodingKey {
        case count, results
    }
    var count: Int?
    var results: Results?
    var types: [EntityTypeGrouping]?
}

struct EntityTypeGrouping : Codable {
    enum CodingKeys: CodingKey {
        case count, domain, type
    }
    var count: Int?
    var domain: Entity.Domain?
    var type: Entity.EntityType?
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
