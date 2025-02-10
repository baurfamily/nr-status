//
//  ChartViews.swift
//  NR Status
//
//  Created by Eric Baur on 10/10/24.
//

import SwiftUI


struct SeriesSelectionView : View {
    var title: String
    @Binding var fields: [SelectableField]
    var singleValue: Bool = false
    
    @State private var isShowingPopover = false
    
    var body: some View {
        DisclosureGroup(title) {
            VStack {
                if singleValue {
                    RadioSelectionView(fields: $fields)
                } else {
                    CheckboxSelectionView(fields: $fields)
                }
            }
        }.padding()
    }
}

struct RadioSelectionView : View {
    @Binding var fields: [SelectableField]
    @State var selectedField: String?

    var body: some View {
        Picker("", selection: $selectedField) {
            ForEach(fields) { field in
                Text(field.id).tag(field.id)
            }
        }
        .pickerStyle(RadioGroupPickerStyle())
        .onChange(of: selectedField) {
            if let selectedField {
                for field in $fields {
                    if field.id == selectedField {
                        field.wrappedValue.isSelected = true
                    } else {
                        field.wrappedValue.isSelected = false
                    }
                }
            }
        }
    }
}

struct CheckboxSelectionView : View {
    @Binding var fields: [SelectableField]

    var body: some View {
        Toggle(
            sources: $fields,
            isOn: \.isSelected
        ) {
            HStack {
                Text("All on/off")
                    .bold()
                Spacer()
            }
            Spacer()
        }
        ForEach($fields) { field in
            Toggle(isOn: field.isSelected) {
                HStack {
                    Text(field.id)
                    Spacer()
                }
            }
        }
    }
}


#Preview("A few options") {
    @Previewable @State var fieldList = SelectableField.wrap([
        "Albert has a field to select",
        "Betty also has a field to select",
        "Carl would like to have a field to select"
    ])
    GroupBox {
        SeriesSelectionView(title: "Select fields...", fields: $fieldList )
        ForEach(fieldList) { field in
            HStack {
                Text(field.id)
                Spacer()
                Text(field.isSelected ? "X" : " ")
            }
        }
    }
}

#Preview("Single selection") {
    @Previewable @State var fieldList = SelectableField.wrap([
        "Albert has a field to select",
        "Betty also has a field to select",
        "Carl would like to have a field to select"
    ])
    GroupBox {
        SeriesSelectionView(title: "Select fields...", fields: $fieldList, singleValue: true )
        ForEach(fieldList) { field in
            HStack {
                Text(field.id)
                Spacer()
                Text(field.isSelected ? "X" : " ")
            }
        }
    }
}
#Preview("A lot of options") {
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
