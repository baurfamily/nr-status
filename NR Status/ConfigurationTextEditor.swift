import AppKit
import SwiftUI

struct ConfigurationTextEditor: NSViewRepresentable {
    @Binding var text: String
    let identifier: String
    var completionScope: (() -> LuaCompletion.Scope)?
    var isExpression = false

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, completionScope: completionScope, isExpression: isExpression)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.setAccessibilityIdentifier(identifier)
        textView.string = text
        textView.delegate = context.coordinator
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.completionScope = completionScope
        context.coordinator.isExpression = isExpression
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.setAccessibilityIdentifier(identifier)
        if textView.string != text {
            textView.string = text
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var completionScope: (() -> LuaCompletion.Scope)?
        var isExpression: Bool

        init(text: Binding<String>, completionScope: (() -> LuaCompletion.Scope)?, isExpression: Bool = false) {
            self.text = text
            self.completionScope = completionScope
            self.isExpression = isExpression
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }

        func textView(
            _ textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange,
            indexOfSelectedItem index: UnsafeMutablePointer<Int>?
        ) -> [String] {
            guard let completionScope else { return [] }
            let scope = completionScope()
            let location = textView.selectedRange().location
            let found = isExpression
                ? LuaCompletion.items(text: textView.string, location: location, scope: scope, isExpression: true)
                : LuaCompletion.bindingItems(text: textView.string, location: location, scope: scope)
            guard !found.items.isEmpty, charRange.location != NSNotFound,
                  found.range.location >= charRange.location else { return [] }
            let prefix = (textView.string as NSString).substring(with: NSRange(
                location: charRange.location, length: found.range.location - charRange.location
            ))
            index?.pointee = 0
            return found.items.map { prefix + $0.insertText }
        }
    }
}
