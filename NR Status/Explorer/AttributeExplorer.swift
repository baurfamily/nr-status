//
//  AttributeExplorer.swift
//  NR Status
//
//  Created by Eric Baur on 3/16/25.
//

import SwiftUI

struct AttributeSummary : View {
    let attribute: Attribute
    @State private var detailPresented: Bool = false
    
    var body : some View {
        HStack {
            Text(attribute.key)
            Spacer()
            
            Button {
                self.detailPresented = true
            } label: {
               Image(systemName: "eye")
            }
            .popover(isPresented: $detailPresented) {
                VStack {
                    Text("popover content")
                    Text("popover content")
                    Text("popover content")
                }.padding(.all)
            }.buttonStyle(.borderless)
            
            Menu {
                Button("Order Now") { print("hi") }
                Button("Adjust Order") { print("hi") }
                Button("Cancel") { print("hi") }
            } label: {
                Image(systemName: "chart.xyaxis.line")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}

struct AttributeGroup : View {
    let title: String
    
    @State var attributes: [Attribute]
    var filterClosure: ((Attribute) -> Bool)
    
    var filteredAttributes: [Attribute] {
        attributes.filter { filterClosure($0) }
    }
    
    var body : some View {
        Text(title).bold()
        ForEach($attributes, id: \.self) { attribute in
            if filteredAttributes.contains(attribute.wrappedValue) {
                NavigationLink(value: attribute.wrappedValue) {
                    AttributeSummary(attribute: attribute.wrappedValue)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct AttributeExplorer : View {
    let event: String
    @State var attributes: [Attribute] = []

    var attributeTypes: [String] {
        Array(Set(attributes.map(\.type))).sorted()
    }
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(attributeTypes, id: \.self) { typeName in
                    AttributeGroup(title: typeName.capitalized, attributes: attributes) { $0.type == typeName }
                }
            }
        }
        .navigationTitle("\(event) attributes")
        .navigationViewStyle(.columns)
        .task {
            Queries().nrql(query: "SELECT keyset() FROM \(event)") { results in
                if let results {
                    self.attributes = results.data.map {
                        Attribute(
                            event: event,
                            type: $0.stringFields["type"]!,
                            key: $0.stringFields["key"]!
                        )
                    }
                }
            }
        }
        
    }
}

#Preview {
    AttributeExplorer(event: "Transaction")
}
