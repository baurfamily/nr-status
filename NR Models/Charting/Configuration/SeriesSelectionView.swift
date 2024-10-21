//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI

struct SelectableField: Identifiable, Hashable {
    let id: String
    var isSelected: Bool = true
    
    static func wrap(_ values: [String]) -> [Self] {
        return values.map { Self(id: $0) }
    }
}

struct SeriesSelectionView : View {
    var title: String
    @Binding var fields: [SelectableField]
    @State private var isShowingPopover = false
    
    var body: some View {
        Button(title) {
            self.isShowingPopover = true
        }
        .popover(
            isPresented: $isShowingPopover
        ) {
            Toggle(
                sources: $fields,
                isOn: \.isSelected
            ) {
                Text("All on/off")
                    .bold()
            }
            ForEach($fields) { field in
                Toggle(isOn: field.isSelected) {
                    Text(field.id)
                }
            }
        }
                    
    }
}


#Preview("A few options") {
    @Previewable @State var selectedFields: Set<String> = []
    @Previewable @State var fieldList = SelectableField.wrap([
        "Albert has a field to select",
        "Betty also has a field to select",
        "Carl would like to have a field to select"
    ])
    GroupBox {
        SeriesSelectionView(title: "Select fields...", fields: $fieldList )
    }
}

#Preview("A lot of options") {
    @Previewable @State var selectedFields: Set<String> = []
    @Previewable @State var fieldList = SelectableField.wrap([
        "Albert has a field to select, first",
        "Betty also has a field to select, first",
        "Carl would like to have a field to select, first",
        "Albert has a field to select, second",
        "Betty also has a field to select, second",
        "Carl would like to have a field to select, second",
        "Albert has a field to select, third",
        "Betty also has a field to select, third",
        "Carl would like to have a field to select, third",
        "Albert has a field to select, fourth",
        "Betty also has a field to select, fourth",
        "Carl would like to have a field to select, fourth",
        "Albert has a field to select, fifth",
        "Betty also has a field to select, fifth",
        "Carl would like to have a field to select, fifth",
        "Albert has a field to select, sixth",
        "Betty also has a field to select, sixth",
        "Carl would like to have a field to select, sixth",
        "Albert has a field to select, seventh",
        "Betty also has a field to select, seventh",
        "Carl would like to have a field to select, seventh",
        "Albert has a field to select, eighth",
        "Betty also has a field to select, eighth",
        "Carl would like to have a field to select, eighth",
        "Albert has a field to select, ninth",
        "Betty also has a field to select, ninth",
        "Carl would like to have a field to select, ninth",
    ])
    GroupBox {
        SeriesSelectionView(title: "Select a lot of fields", fields: $fieldList )
    }
}
