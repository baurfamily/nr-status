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
            let isOn = configuration.isOn
            let labelSegment = configuration.label
                .frame(width: 120, height: 24)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.white)
            let symbolSegment = Text(isOn ? "-" : "+")
                .frame(width: 40, height: 24)
            HStack(spacing: 0) {
                if isOn {
                    symbolSegment
                    labelSegment
                } else {
                    labelSegment
                    symbolSegment
                }
            }
            .padding(2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
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
