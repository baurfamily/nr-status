//
//  TitleShiftToggleStyle.swift
//  NR Status
//
//  Created by Eric Baur on 4/5/25.
//

import SwiftUI

struct TitleShiftToggleStyle: ToggleStyle {
    var activeColor: Color = .green

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Picker("", selection: configuration.$isOn) {
                if configuration.isOn {
                    Text("-").tag(false)
                    configuration.label.tag(true)
                } else {
                    configuration.label.tag(false)
                    Text("+").tag(true)
                }
            }
            .pickerStyle(.segmented)
            // animation doesn't work, probably because the use of a picker
            // and the changes in the labels/text aren't animatable
            .onTapGesture {
                withAnimation(.spring()) {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

extension ToggleStyle where Self == TitleShiftToggleStyle {

    static var titleShift: TitleShiftToggleStyle { .init() }
    static func titleShift(activeColor: Color) -> Self {
        return self.init(activeColor: activeColor)
    }
}
