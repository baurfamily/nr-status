//
//  EditorFocus.swift
//  NR Status
//

import SwiftUI
import AppKit

/// Placed behind a code editor so the text view drawn over it can be given the keyboard.
struct EditorFocusAnchor: NSViewRepresentable {
    let focusRequested: Bool
    let onFocused: () -> Void

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ anchor: NSView, context: Context) {
        guard focusRequested else { return }
        // the editor is laid out after this view, so wait a beat
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let window = anchor.window, let root = window.contentView else { return }
            let area = anchor.convert(anchor.bounds, to: nil)
            if let textView = Self.textViews(in: root).first(where: { view in
                let frame = view.convert(view.bounds, to: nil)
                return area.contains(CGPoint(x: frame.midX, y: frame.midY))
            }) {
                window.makeFirstResponder(textView)
            }
            onFocused()
        }
    }

    private static func textViews(in view: NSView) -> [NSTextView] {
        var found: [NSTextView] = []
        if let text = view as? NSTextView, text.isEditable { found.append(text) }
        for sub in view.subviews { found += textViews(in: sub) }
        return found
    }
}
