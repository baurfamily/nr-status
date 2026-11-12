//
//  AttributeListItemView.swift
//  NR Status
//
//  Created by Eric Baur on 3/18/25.
//

import SwiftUI

struct RemovablePill : View {
    let text: String
    let textColor: Color
    let fill: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                Image(systemName: "xmark.app")
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill)
            )
        }
    }
}

struct AttributeListItemView : View {
    let attribute: Attribute
    @Binding var query: QueryBuilder
    
    @State private var detailPresented: Bool = false
    @State private var summaryStats: AttributeSummary?
    
    private var selectBinding: Binding<Bool> {
        Binding(
            get: { query.contains(attribute: attribute) },
            set: { $0 ? query.add(attribute: attribute) : query.remove(attribute: attribute) }
        )
    }

    private var facetBinding: Binding<Bool> {
        Binding(
            get: { query.contains(facet: attribute) },
            set: { $0 ? query.add(facet: attribute) : query.remove(facet: attribute) }
        )
    }

    func makeBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: { query.contains(aggregate: key, with: attribute) },
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
            
            if query.contains(attribute: attribute) {
                RemovablePill(text: "select", textColor: .black, fill: .yellow) {
                    query.remove(attribute: attribute)
                }
            }
            if query.contains(facet: attribute) {
                RemovablePill(text: "facet", textColor: .black, fill: .green) {
                    query.remove(facet: attribute)
                }
            }
            ForEach(query.aggregates.filter { $0.attribute == attribute }) { agg in
                RemovablePill(text: agg.name, textColor: .white, fill: .blue) {
                    query.remove(aggregate: agg.name, with: attribute)
                }
            }

            Spacer().frame(width: 10)
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
                        self.summaryStats = await AttributeSummary.generate(from: attribute)
                    }
            }.buttonStyle(.borderless)
            
            Menu {
                
                Toggle(isOn: selectBinding) { Text("Select") }
                    .disabled(query.isFaceted)

                Toggle(isOn: facetBinding) { Text("Facet") }

                Divider()
                Group {
                    Toggle(isOn: makeBinding(for: "count")) { Text("count") }
                    Toggle(isOn: makeBinding(for: "uniqueCount")) { Text("Count Unique") }
                    
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
