//
//  MarkdownView.swift
//  NR Status
//

import SwiftUI

/// The block-level Markdown that notebook cells use: headings, paragraphs, lists,
/// quotes, code blocks and rules. Inline styling is left to `AttributedString`.
enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullets([String])
    case numbered([String])
    case quote(String)
    case code(String)
    case rule
}

enum MarkdownParser {
    static func blocks(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var numbered: [String] = []
        var quote: [String] = []

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))) }
            if !bullets.isEmpty { blocks.append(.bullets(bullets)) }
            if !numbered.isEmpty { blocks.append(.numbered(numbered)) }
            if !quote.isEmpty { blocks.append(.quote(quote.joined(separator: " "))) }
            paragraph = []; bullets = []; numbered = []; quote = []
        }

        var code: [String]?
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if code != nil {
                if trimmed == "```" {
                    blocks.append(.code(code!.joined(separator: "\n")))
                    code = nil
                } else {
                    code!.append(line)
                }
            } else if trimmed.hasPrefix("```") {
                flush()
                code = []
            } else if trimmed.isEmpty {
                flush()
            } else if let heading = headingParts(trimmed) {
                flush()
                blocks.append(.heading(level: heading.level, text: heading.text))
            } else if trimmed.count >= 3, trimmed.allSatisfy({ $0 == "-" }) || trimmed.allSatisfy({ $0 == "*" }) {
                flush()
                blocks.append(.rule)
            } else if let item = bulletItem(trimmed) {
                if bullets.isEmpty { flush() }
                bullets.append(item)
            } else if let item = numberedItem(trimmed) {
                if numbered.isEmpty { flush() }
                numbered.append(item)
            } else if trimmed.hasPrefix(">") {
                if quote.isEmpty { flush() }
                quote.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
            } else {
                if !bullets.isEmpty || !numbered.isEmpty || !quote.isEmpty { flush() }
                paragraph.append(trimmed)
            }
        }
        if let code { blocks.append(.code(code.joined(separator: "\n"))) }
        flush()
        return blocks
    }

    private static func headingParts(_ line: String) -> (level: Int, text: String)? {
        let level = line.prefix { $0 == "#" }.count
        guard (1...6).contains(level), line.dropFirst(level).first == " " else { return nil }
        return (level, line.dropFirst(level).trimmingCharacters(in: .whitespaces))
    }

    private static func bulletItem(_ line: String) -> String? {
        guard let first = line.first, "-*+".contains(first), line.dropFirst().first == " " else { return nil }
        return line.dropFirst(2).trimmingCharacters(in: .whitespaces)
    }

    private static func numberedItem(_ line: String) -> String? {
        let digits = line.prefix { $0.isNumber }
        let rest = line.dropFirst(digits.count)
        guard !digits.isEmpty, rest.hasPrefix(". ") else { return nil }
        return rest.dropFirst(2).trimmingCharacters(in: .whitespaces)
    }

    /// Inline Markdown (emphasis, code, links) as styled text.
    static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }

    // MARK: HTML

    static func html(_ text: String) -> String {
        blocks(text).map { block -> String in
            switch block {
            case .heading(let level, let text): "<h\(level)>\(inlineHTML(text))</h\(level)>"
            case .paragraph(let text): "<p>\(inlineHTML(text))</p>"
            case .bullets(let items): "<ul>" + items.map { "<li>\(inlineHTML($0))</li>" }.joined() + "</ul>"
            case .numbered(let items): "<ol>" + items.map { "<li>\(inlineHTML($0))</li>" }.joined() + "</ol>"
            case .quote(let text): "<blockquote>\(inlineHTML(text))</blockquote>"
            case .code(let text): "<pre>\(escape(text))</pre>"
            case .rule: "<hr>"
            }
        }.joined(separator: "\n")
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func inlineHTML(_ text: String) -> String {
        var html = escape(text)
        let rules: [(String, String)] = [
            (#"`([^`]+)`"#, "<code>$1</code>"),
            (#"\*\*(.+?)\*\*"#, "<strong>$1</strong>"),
            (#"\*(.+?)\*"#, "<em>$1</em>"),
            (#"\[([^\]]+)\]\(([^)]+)\)"#, #"<a href="$2">$1</a>"#),
        ]
        for (pattern, template) in rules {
            html = html.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        return html
    }
}

/// Renders Markdown text.
struct MarkdownView: View {
    let blocks: [MarkdownBlock]

    init(text: String) { blocks = MarkdownParser.blocks(text) }
    init(blocks: [MarkdownBlock]) { self.blocks = blocks }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(MarkdownParser.inline(text))
                .font(level == 1 ? .title : level == 2 ? .title2 : level == 3 ? .title3 : .headline)
        case .paragraph(let text):
            Text(MarkdownParser.inline(text))
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text("•  ") + Text(MarkdownParser.inline(item))
                }
            }
        case .numbered(let items):
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Text("\(index + 1).  ") + Text(MarkdownParser.inline(item))
                }
            }
        case .quote(let text):
            Text(MarkdownParser.inline(text))
                .foregroundStyle(.secondary)
                .padding(.leading, 10)
                .overlay(alignment: .leading) { Rectangle().fill(.secondary).frame(width: 3) }
        case .code(let text):
            Text(text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        case .rule:
            Divider()
        }
    }
}

#Preview {
    MarkdownView(text: "# Title\n\nSome *emphasis* and `code`.\n\n- one\n- two\n\n> quoted")
        .padding()
}
