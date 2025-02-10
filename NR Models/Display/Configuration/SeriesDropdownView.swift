//
//  SeriesDropdownView.swift
//  NR Status
//
//  Created by Eric Baur on 02/09/25.
//

import SwiftUI


struct SeriesDropdownView: View {
    var title: String
    var fields: [String]
    @Binding var selection: String?
    var includeNone: Bool = false
    
    @State private var isShowingPopover = false
    
    var body: some View {
        Picker(title, selection: $selection) {
            if includeNone {
                Text(" - none - ").tag(nil as String?)
            }
            ForEach(fields, id: \.self) { field in
                Text(field).tag(field)
            }
        }
    }
}

#Preview("A few options") {
    @Previewable @State var selectedField: String?
    @Previewable @State var fieldList = SelectableField.wrap([
        "Albert has a field to select",
        "Betty also has a field to select",
        "Carl would like to have a field to select"
    ])
    GroupBox {
        SeriesDropdownView(title: "Select fields...", fields:fieldList.map(\.id), selection: $selectedField )
        if let field = selectedField {
            Text("Selected: \(field)")
        } else {
            Text("Nothing selected yet...")
        }
    }
}

//#Preview("Single selection") {
//    @Previewable @State var fieldList = SelectableField.wrap([
//        "Albert has a field to select",
//        "Betty also has a field to select",
//        "Carl would like to have a field to select"
//    ])
//    GroupBox {
//        SeriesSelectionView(title: "Select fields...", fields: $fieldList, singleValue: true )
//        ForEach(fieldList) { field in
//            HStack {
//                Text(field.id)
//                Spacer()
//                Text(field.isSelected ? "X" : " ")
//            }
//        }
//    }
//}
//#Preview("A lot of options") {
//    @Previewable @State var fieldList = SelectableField.wrap([
//        "Albert has a field to select, first",
//        "Betty also has a field to select, first",
//        "Carl would like to have a field to select, first",
//        "Albert has a field to select, second",
//        "Betty also has a field to select, second",
//        "Carl would like to have a field to select, second",
//        "Albert has a field to select, third",
//        "Betty also has a field to select, third",
//        "Carl would like to have a field to select, third",
//        "Albert has a field to select, fourth",
//        "Betty also has a field to select, fourth",
//        "Carl would like to have a field to select, fourth",
//        "Albert has a field to select, fifth",
//        "Betty also has a field to select, fifth",
//        "Carl would like to have a field to select, fifth",
//        "Albert has a field to select, sixth",
//        "Betty also has a field to select, sixth",
//        "Carl would like to have a field to select, sixth",
//        "Albert has a field to select, seventh",
//        "Betty also has a field to select, seventh",
//        "Carl would like to have a field to select, seventh",
//        "Albert has a field to select, eighth",
//        "Betty also has a field to select, eighth",
//        "Carl would like to have a field to select, eighth",
//        "Albert has a field to select, ninth",
//        "Betty also has a field to select, ninth",
//        "Carl would like to have a field to select, ninth",
//    ])
//    GroupBox {
//        SeriesSelectionView(title: "Select a lot of fields", fields: $fieldList )
//    }
//}
