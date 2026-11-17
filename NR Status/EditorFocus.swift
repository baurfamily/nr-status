//
//  EditorFocus.swift
//  NR Status
//

import SwiftUI
import AppKit

/// Placed behind a code editor so the text view drawn over it can be given the keyboard.
struct EditorFocusAnchor: NSViewRepresentable {
    let focusRequested: Bool
    var onRun: (() -> Void)? = nil
    let onFocused: () -> Void

    final class AnchorView: NSView {
        var onRun: (() -> Void)?
    }

    func makeNSView(context: Context) -> AnchorView { AnchorView() }

    func updateNSView(_ anchor: AnchorView, context: Context) {
        anchor.onRun = onRun
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

    static func runQuery(for editor: NSTextView) -> Bool {
        guard let window = editor.window, let root = window.contentView else { return false }
        let frame = editor.convert(editor.visibleRect.intersection(editor.bounds), to: nil)
        let point = CGPoint(x: frame.midX, y: frame.midY)
        guard !frame.isEmpty, let action = runAction(in: root, at: point) else { return false }
        action()
        return true
    }

    private static func runAction(in view: NSView, at point: CGPoint) -> (() -> Void)? {
        if let anchor = view as? AnchorView, anchor.convert(anchor.bounds, to: nil).contains(point),
           let action = anchor.onRun { return action }
        return view.subviews.lazy.compactMap { runAction(in: $0, at: point) }.first
    }

    private static func textViews(in view: NSView) -> [NSTextView] {
        var found: [NSTextView] = []
        if let text = view as? NSTextView, text.isEditable { found.append(text) }
        for sub in view.subviews { found += textViews(in: sub) }
        return found
    }
}
