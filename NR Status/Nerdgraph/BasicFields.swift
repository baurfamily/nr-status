//
//  Basic.swift
//  NR Status
//
//  Created by Eric Baur on 9/22/24.
//

struct Root : Decodable {
    var data: Data?
}

struct Data : Decodable {
    var actor: Actor?
}

struct Actor : Decodable {
    var user: User?
    var accounts: [Account]?
    var entitySearch: EntitySearch?
    var nrql: NrdbResultContainer?
}

struct EntitySearch : Decodable {
    var count: Int?
    var results: Results?
    var types: [EntityTypeGrouping]?
}

struct EntityTypeGrouping : Decodable {
    enum CodingKeys: String, CodingKey {
        case count, domain, entityType = "type"
    }
    var count: Int?
    var domain: Entity.Domain?
    var entityType: String?
}

struct Results : Decodable {
    var nextCursor: String?
    var entities: [Entity]?
}

struct Account : Decodable {
    var id: Int?
    var name: String?
}

struct User : Decodable {
    var email: String?
}
