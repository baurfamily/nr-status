//
//  CompletionKeyRouter.swift
//  NR Status
//

import AppKit

/// The editor's completion panel is meant to forward typing to the editor and to commit on Return,
/// but its SwiftUI list takes first responder and swallows those keys. This hands keys typed into
/// the panel back to the panel's own key handler, and also lets Tab commit.
@MainActor
enum CompletionKeyRouter {
    private static var monitor: Any?

    private static let upArrow: UInt16 = 126
    private static let downArrow: UInt16 = 125
    private static let tab: UInt16 = 48
    private static let returnKey: UInt16 = 36

    static func installIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let panel = event.window, String(describing: type(of: panel)) == "CompletionPanel",
                  let handler = panel.contentView
            else { return event }

            // the list handles moving the selection itself
            if event.keyCode == upArrow || event.keyCode == downArrow { return event }

            handler.keyDown(with: event.keyCode == tab ? returnEvent(like: event) ?? event : event)
            return nil
        }
    }

    private static func returnEvent(like event: NSEvent) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown, location: event.locationInWindow, modifierFlags: [], timestamp: event.timestamp,
            windowNumber: event.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: returnKey
        )
    }
}
