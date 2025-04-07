//
//  ChartType.swift
//  NR Status
//
//  Created by Eric Baur on 3/4/25.
//

import AppIntents
import SwiftUI

enum ChartType : String, CaseIterable, AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Chart Type"
    
    static var caseDisplayRepresentations: [ChartType : DisplayRepresentation]  = [
        .bar: .init(stringLiteral: "Bar"),
        .billboard: .init(stringLiteral: "Billboard"),
        .line: .init(stringLiteral: "Line"),
        .plot: .init(stringLiteral: "Plot"),
        .pie: .init(stringLiteral: "Pie"),
        .table: .init(stringLiteral: "Table")
    ]
    
    case line, billboard, plot, pie, bar, table
    
    // want to refactor this to look at chart properties more deeply
    // for example, plot should only be used if there are at least two numeric fields
    static func cases(for resultContainer: NrdbResultContainer) -> [ChartType] {
        if resultContainer.isTimeseries {
            return [ .line, .table, .plot, .bar ]
        } else if resultContainer.isEvents {
            return [ .line, .table, .plot ]
        } else if resultContainer.isComparable {
            return [ .billboard, .line, .table ]
        } else {
            return [ .billboard, .plot, .bar, .pie, .table ]
        }
    }
    
    var shortcut: KeyboardShortcut {
        switch(self) {
        case .bar: return .init( "b", modifiers: [.command, .option] )
        case .billboard: return .init( "b", modifiers: [.command, .shift, .option] )
        case .line: return .init( "l", modifiers: [.command, .option] )
        case .pie: return .init( "p", modifiers: [.command, .option] )
        case .table: return .init( "t", modifiers: [.command, .option] )
        case .plot: return .init( "p", modifiers: [.command, .shift, .option] )
        }
    }
    
    func isSupported(for resultContainer: NrdbResultContainer) -> Bool {
        return ChartType.cases(for: resultContainer).contains(self)
    }
}
