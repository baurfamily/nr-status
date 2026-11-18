//
//  CompletionKeyRouter.swift
//  NR Status
//

import AppKit

/// Routes completion-panel typing and editor Return keys without letting the panel swallow shortcuts.
@MainActor
enum CompletionKeyRouter {
    static let returnAcceptsAutocompleteKey = "returnAcceptsAutocomplete"
    static let returnRunsQueryKey = "returnRunsQuery"

    enum ReturnAction {
        case acceptCompletion, insertNewline, runQuery, passThrough
    }

    private static var monitor: Any?

    private static let upArrow: UInt16 = 126
    private static let downArrow: UInt16 = 125
    private static let tab: UInt16 = 48
    private static let returnKey: UInt16 = 36
    private static let enterKey: UInt16 = 76

    static func returnAction(
        modifiers: NSEvent.ModifierFlags, completionVisible: Bool, defaults: UserDefaults = .standard
    ) -> ReturnAction {
        let modifiers = modifiers.intersection([.command, .shift, .option, .control])
        if modifiers == .command { return .runQuery }
        if modifiers == .shift { return .insertNewline }
        guard modifiers.isEmpty else { return .passThrough }
        if completionVisible, defaults.object(forKey: returnAcceptsAutocompleteKey) as? Bool ?? true {
            return .acceptCompletion
        }
        return (defaults.object(forKey: returnRunsQueryKey) as? Bool ?? true) ? .runQuery : .insertNewline
    }

    static func installIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { route($0) }
    }

    static func route(_ event: NSEvent, defaults: UserDefaults = .standard) -> NSEvent? {
        guard let panel = event.window, String(describing: type(of: panel)) == "CompletionPanel",
              let handler = panel.contentView
        else {
            guard event.keyCode == returnKey || event.keyCode == enterKey,
                  let editor = event.window?.firstResponder as? NSTextView, editor.isEditable,
                  returnAction(modifiers: event.modifierFlags, completionVisible: false, defaults: defaults) == .runQuery,
                  EditorFocusAnchor.runQuery(for: editor) else { return event }
            return nil
        }

        // the list should move the selection itself, but it isn't reliably first responder
        if event.keyCode == upArrow || event.keyCode == downArrow {
            guard let table = findTable(in: handler) else { return event }
            if panel.firstResponder !== table { panel.makeFirstResponder(table) }
            table.keyDown(with: event)
            return nil
        }

        if event.keyCode == returnKey || event.keyCode == enterKey {
            let action = returnAction(modifiers: event.modifierFlags, completionVisible: true, defaults: defaults)
            switch action {
            case .acceptCompletion:
                handler.keyDown(with: returnEvent(like: event) ?? event)
                return nil
            case .insertNewline, .runQuery:
                let editor = completionEditor(for: panel)
                handler.keyDown(with: escapeEvent(like: event) ?? event)
                if action == .runQuery, let editor, EditorFocusAnchor.runQuery(for: editor) { return nil }
                if event.modifierFlags.contains(.command) { return event }
                editor?.insertNewline(nil)
                return nil
            case .passThrough:
                handler.keyDown(with: escapeEvent(like: event) ?? event)
                return event
            }
        }

        handler.keyDown(with: event.keyCode == tab ? returnEvent(like: event) ?? event : event)
        return nil
    }

    private static func completionEditor(for panel: NSWindow) -> NSTextView? {
        let windows = [panel.parent, NSApp.mainWindow].compactMap { $0 } + NSApp.orderedWindows
        return windows.lazy.filter { $0 !== panel }
            .compactMap { $0.firstResponder as? NSTextView }.first { $0.isEditable }
    }

    private static func findTable(in view: NSView) -> NSTableView? {
        if let table = view as? NSTableView { return table }
        for sub in view.subviews { if let found = findTable(in: sub) { return found } }
        return nil
    }

    private static func escapeEvent(like event: NSEvent) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown, location: event.locationInWindow, modifierFlags: [], timestamp: event.timestamp,
            windowNumber: event.windowNumber, context: nil, characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false, keyCode: 53
        )
    }

    private static func returnEvent(like event: NSEvent) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown, location: event.locationInWindow, modifierFlags: [], timestamp: event.timestamp,
            windowNumber: event.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: returnKey
        )
    }
}
