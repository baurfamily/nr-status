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
                           columnChange deltaColumn: Int, newText text: String) async throws {}

    func closeDocument() async throws { isOpen = false }

    // MARK: Events and diagnostics

    let events = PassthroughSubject<LanguageServiceEvent, Never>()
    let diagnostics = CurrentValueSubject<Set<TextLocated<Message>>, Never>(Set())
    let extraActions = CurrentValueSubject<[ExtraAction], Never>([])

    // MARK: Completion

    let completionTriggerCharacters = CurrentValueSubject<[Character], Never>([])

    func completions(at location: Int, reason: CompletionTriggerReason) async throws -> Completions {
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
