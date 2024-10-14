//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI

struct SeriesSelectionView : View {
    let fieldList: [String]
    
    @State private var show = false
    @Binding var selectedFields: Set<String>
    
    func toggle(field: String) {
        if selectedFields.contains(field) {
            selectedFields.remove(field)
        } else {
            self.selectedFields.insert(field)
        }
    }
    
    var body: some View {
        Menu {
            ForEach(fieldList, id: \.self) { field in
                Button(field, action: { toggle(field: field) })
            }
        } label: {
            Text(selectedFields.joined(separator: ", "))
        }
    }
    
}
