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
        case user, accounts
    }
    var user: User?
    var accounts: [Account]?
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
