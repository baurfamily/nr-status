//
//  AttributeGroupView.swift
//  NR Status
//
//  Created by Eric Baur on 3/18/25.
//

import SwiftUI

struct AttributeGroupView : View {
    let title: String
    @Binding var query: QueryBuilder
    
    @Binding var attributes: [Attribute]
    var filterClosure: ((Attribute) -> Bool)
    
    var filteredAttributes: [Attribute] {
        attributes.filter { filterClosure($0) }
    }
    
    var body : some View {
        Section(title) {
            ForEach(filteredAttributes) { attribute in
                NavigationLink(value: attribute) {
                    AttributeListItemView(attribute: attribute, query: $query)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
