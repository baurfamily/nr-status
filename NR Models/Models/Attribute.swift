//
//  Attribute.swift
//  NR Status
//
//  Created by Eric Baur on 3/15/25.
//

import SwiftUI

struct Attribute : Hashable, Identifiable {
    var id: String { self.key }

    let event: String
    let type: String
    let key: String

    /// Builds attributes from a `keyset()` result. NRDB can return either one
    /// row per attribute (`key` + `type`) or grouped lists
    /// (`stringKeys`, `numericKeys`, `booleanKeys`).
    static func attributes(event: String, fromKeyset container: NrdbResultContainer) -> [Attribute] {
        var found: [Attribute] = []
        var seen = Set<String>()

        func add(_ key: String, type: String) {
            guard seen.insert(key).inserted else { return }
            found.append(Attribute(event: event, type: type, key: key))
        }

        // boolean first: NRDB also lists booleans under numericKeys
        let groups = [("booleanKeys", "boolean"), ("stringKeys", "string"), ("numericKeys", "numeric")]

        for row in container.data {
            if let key = row.stringFields["key"] {
                add(key, type: row.stringFields["type"] ?? "string")
            }
            for (field, type) in groups {
                for key in row.stringArrayFields[field] ?? [] {
                    add(key, type: type)
                }
            }
        }
        return found.sorted { $0.key < $1.key }
    }
}
