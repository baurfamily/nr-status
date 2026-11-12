//
//  NrqlLanguageService.swift
//  NR Status
//

import SwiftUI
import Combine
import LanguageSupport

/// Gives the code editor NRQL completions. One instance serves one cell.
final class NrqlLanguageService: LanguageService {
    private let metadata: NrqlMetadataProviding
    private let lock = NSLock()
    private var openedText = ""
    private var textSource: (() -> String)?
    private var lastChange = Date.distantPast
    private var completionAction: (() -> Void)?

    /// The editor's own "show completions" action, used to reopen the panel after a separator.
    func setCompletionAction(_ action: (() -> Void)?) {
        lock.withLock { completionAction = action }
    }
    /// Set to false to only show completions when asked for explicitly.
    var popsUpWhileTyping = true
    private(set) var isOpen = false

    init(metadata: NrqlMetadataProviding = NrqlMetadata.shared) {
        self.metadata = metadata
    }

    /// The editor only reports edits, so completion reads the live text from here.
    func setTextSource(_ source: @escaping () -> String) {
        lock.withLock { textSource = source }
    }

    private var currentText: String {
        lock.withLock { textSource?() ?? openedText }
    }

    // MARK: Document synchronisation

    func openDocument(with text: String, locationService: LocationService) async throws {
        lock.withLock { openedText = text }
        isOpen = true
    }

    func documentDidChange(position changeLocation: Int, changeInLength delta: Int, lineChange deltaLine: Int,
                           columnChange deltaColumn: Int, newText text: String) async throws {
        lock.withLock { lastChange = Date() }

        // The editor closes its panel when a word ends. Where the next word is a name we can
        // list, such as after a comma, bring it straight back.
        guard delta == 1, [" ", ",", "("].contains(text) else { return }
        let source = currentText
        guard NrqlCompletion.offersAfterSeparator(text: source, location: changeLocation + 1) else { return }
        try await Task.sleep(for: .milliseconds(100))
        let action = lock.withLock { completionAction }
        await MainActor.run { action?() }
    }

    func closeDocument() async throws { isOpen = false }

    // MARK: Events and diagnostics

    let events = PassthroughSubject<LanguageServiceEvent, Never>()
    let diagnostics = CurrentValueSubject<Set<TextLocated<Message>>, Never>(Set())
    let extraActions = CurrentValueSubject<[ExtraAction], Never>([])

    // MARK: Completion

    let completionTriggerCharacters = CurrentValueSubject<[Character], Never>([])

    func completions(at location: Int, reason: CompletionTriggerReason) async throws -> Completions {
        // the editor asks right after a keystroke when it wants to pop up on its own
        if !popsUpWhileTyping, case .standard = reason,
           lock.withLock({ Date().timeIntervalSince(lastChange) }) < 0.4 {
            return .none
        }
        let (items, range) = await NrqlCompletion.items(text: currentText, location: location, metadata: metadata)
        guard !items.isEmpty else { return .none }

        return Completions(
            isIncomplete: false,
            items: items.enumerated().map { index, item in
                Completions.Completion(
                    id: index,
                    rowView: { _ in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text(item.detail ?? item.kind.label).foregroundStyle(.secondary).font(.caption)
                        }
                    },
                    documentationView: Text("\(item.kind.label.capitalized): \(item.name)"),
                    selected: index == 0,
                    sortText: String(format: "%06d", index),
                    filterText: item.name,
                    insertText: item.insertText,
                    insertRange: range,
                    commitCharacters: [],
                    refine: { nil }
                )
            }
        )
    }

    // MARK: Unused features

    func tokens(for lineRange: Range<Int>) async throws -> [[(token: LanguageConfiguration.Token, range: NSRange)]] {
        Array(repeating: [], count: lineRange.count)
    }

    func info(at location: Int) async throws -> (view: any View, anchor: NSRange?)? { nil }

    func capabilities() async throws -> (any View)? { nil }
}
