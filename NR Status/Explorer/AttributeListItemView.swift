//
//  AttributeListItemView.swift
//  NR Status
//
//  Created by Eric Baur on 3/18/25.
//

import SwiftUI

//struct AggregateToggle : View {
//    var title: String
//    var function: String
//    var attribute: Attribute
//    @Binding var query: QueryBuilder
//    
//    @State var toggles:[String:Bool] = [:]
//
//    func makeBinding(for key: String) -> Binding<Bool> {
//        return Binding(
//            get: { return toggles[key] ?? false },
//            set: { newVal in toggles[key] = newVal }
//        )
//    }
//    
//    var body: some View {
//        Toggle(isOn: makeBinding(for: attribute.key)) {
//            Text(title)
//        }
//    }
//}

struct AttributeListItemView : View {
    let attribute: Attribute
    @Binding var query: QueryBuilder
    
    @State private var detailPresented: Bool = false
    @State private var summaryStats: AttributeSummary?
    
    @State var toggles:[String:Bool] = [:]
    
    func makeBinding(for key: String) -> Binding<Bool> {
        return Binding(
            get: {
                query.contains(aggregate: key, with: attribute)
            },
            set: { newVal in
                if newVal {
                    query.add(aggregate: key, with: attribute)
                } else {
                    query.remove(aggregate: key, with: attribute)
                }
            }
        )
    }
    
    
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
                    if let summaryStats {
                        AttributeSummaryView(summary: summaryStats)
                    }
                }.padding(.all)
                    .task {
                        Task {
                            self.summaryStats = await AttributeSummary.generate(from: attribute)
                        }
                    }
            }.buttonStyle(.borderless)
            
            Menu {
                
                Toggle(isOn: Binding(
                    get: { query.contains(attribute: attribute) },
                    set: { $0 ? query.add(attribute: attribute) : query.remove(attribute: attribute)}
                )) { Text("Select") }
                    .disabled(query.isFaceted)
                
                Toggle(isOn: Binding(
                    get: { query.contains(facet: attribute) },
                    set: { newVal in
                        if newVal {
                            query.add(facet: attribute)
                        } else {
                            query.remove(facet: attribute)
                        }
                    }
                )) { Text("Facet") }
                
                Divider()
                Group {
                    Toggle(isOn: makeBinding(for: "count")) { Text("count") }
                    Toggle(isOn: makeBinding(for: "countUnique")) { Text("Count Unique") }
                    
                    if attribute.type == "numeric" {
                        Divider()
                        Toggle(isOn: makeBinding(for: "average")) {
                            Text("Average")
                        }
                        Toggle(isOn: makeBinding(for: "stddev")) {
                            Text("Std. Dev.")
                        }
                        Toggle(isOn: makeBinding(for: "min")) {
                            Text("Minimum")
                        }
                        Toggle(isOn: makeBinding(for: "max")) {
                            Text("Maximum")
                        }
                    }
                }.disabled(!query.allowsAggregates) // a little simplistic
                
            } label: {
                Image(systemName: "chart.xyaxis.line")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .buttonStyle(.borderless)
    }
}

#Preview {
    @Previewable @State var query = QueryBuilder(event: "Test")
    var attributeShort = Attribute(event: "Test", type: "numeric", key: "testAttr")
    var attributeLong  = Attribute(event: "Test", type: "numeric", key: "testAttr.with.a.long.name-that-we_need_toFit")
    var attributeString = Attribute(event: "Test", type: "string", key: "testAttrString")
    
    ScrollView {
        LazyVStack {
            Text(query.nrql)
            AttributeListItemView(attribute: attributeShort, query: $query)
            AttributeListItemView(attribute: attributeLong, query: $query)
            AttributeListItemView(attribute: attributeString, query: $query)
        }
    }
}
