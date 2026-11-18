import Testing
import Foundation
import Darwin
import SwiftUI
@testable import NR_Status

struct AIAssistTests {
    @MainActor @Test func promptIncludesFormatBindingsAndLiveSourceButNotCachedResults() throws {
        let document = NRQL_EditorDocument(text: """
            ---
            bindings:
              - name: service
                value: Checkout
            ---

            ```cell_config
            var: traffic
            ```
            ```lua
            return { rows = {} }
            ```
            """)
        let cell = document.cells[1]
        cell.query.text = cell.storedText(forEditorText: "return { rows = { { requests = 1 } } }")
        cell.query.setState(.loaded(try JSONDecoder().decode(NrdbResultContainer.self, from: Data(
            #"{"nrql":"","results":[{"cachedPrivateValue":1234}],"metadata":{}}"#.utf8
        ))))
        let prompt = AIAssist.prompt(
            request: "Chart the request count", document: document, target: .init(cellID: cell.id)
        )
        #expect(prompt.contains("cell 2 (lua)"))
        #expect(prompt.contains("value: Checkout"))
        #expect(prompt.contains("var: traffic"))
        #expect(prompt.contains("requests = 1"))
        #expect(prompt.contains("config.accounts"))
        #expect(prompt.contains("results.name.rows"))
        #expect(prompt.contains("do not output another frontmatter"))
        #expect(prompt.contains("Chart the request count"))
        #expect(prompt.contains("Valid output replaces the target automatically"))
        #expect(!prompt.contains("cachedPrivateValue"))
    }

    @Test func mixedResponseInsertsEditableCellsWithoutReplacingOrRunning() throws {
        var document = NRQL_EditorDocument(text: "```nrql\nSELECT 1\n```\n\n```lua\nreturn {}\n```")
        let originalIDs = document.cells.map(\.id)
        let originalText = document.cells.map(\.text)
        let response = """
            Here is a request count and a note.

            ```cell_config
            title: Requests
            var: requests
            chart: billboard
            ```
            ```nrql
            SELECT count(*) AS requests FROM Transaction
            ```

            Adjust the time range as needed.
            """
        let first = try AIAssist.insert(response, into: &document, target: .init(cellID: originalIDs[0]))
        #expect(document.cells.map(\.kind) == [.nrql, .markdown, .nrql, .markdown, .lua])
        #expect(document.cells[0].id == originalIDs[0])
        #expect(document.cells[4].id == originalIDs[1])
        #expect(document.cells[0].text == originalText[0])
        #expect(document.cells[4].text == originalText[1])
        #expect(first == document.cells[1].id)
        #expect(document.focusedCellId == nil)
        #expect(document.cells[2].query.resultNames == ["requests"])
        #expect(document.cells.allSatisfy { !$0.query.isRunning && !$0.query.hasResult })
        let reopened = NRQL_EditorDocument(text: document.text)
        #expect(reopened.cells.map(\.kind) == document.cells.map(\.kind))
        #expect(reopened.cells.map(\.text) == document.cells.map(\.text))
    }

    @Test func documentDraftMovesFrontmatterToTopAndKeepsGraphQLVariables() throws {
        var document = NRQL_EditorDocument(text: "Existing notes")
        try AIAssist.insert("""
            ---
            accounts: [123]
            ---

            ```graphql
            query User($id: Int!) { actor { account(id: $id) { name } } }
            ```
            ```variables
            {"id": {{ config.accounts[1] }}}
            ```
            """, into: &document, target: .init(isDocument: true))
        #expect(document.cells.map(\.kind) == [.config, .markdown, .nerdgraph])
        #expect(document.cells[1].text == "Existing notes")
        #expect(try document.connection.get().accountIds == [123])
        #expect(document.cells[2].query.variables.contains("config.accounts[1]"))
        #expect(NRQL_EditorDocument(text: document.text).text == document.text)
    }

    @Test func outerDocumentFenceIsRemovedButExecutableAndUnknownFencesArePreserved() throws {
        let inner = "# Draft\n\n```lua\nreturn { rows = {} }\n```"
        #expect(AIAssist.responseSource("````markdown\n\(inner)\n````") == inner)
        #expect(AIAssist.responseSource("```nrmd\r\n# Heading\r\n```") == "# Heading")
        #expect(AIAssist.responseSource("```lua\nreturn {}\n```") == "```lua\nreturn {}\n```")
        #expect(AIAssist.responseSource("```swift\nlet x = 1\n```") == "```swift\nlet x = 1\n```")
        var document = NRQL_EditorDocument(text: "")
        try AIAssist.insert("````markdown\n\(inner)\n````", into: &document, target: .init(isDocument: true))
        #expect(document.cells.map(\.kind) == [.markdown, .lua])
    }

    @Test(arguments: [UUID().uuidString, "not-a-uuid"])
    func generatedWidgetIdentityIsNotReused(identity: String) throws {
        var document = NRQL_EditorDocument(text: "")
        try AIAssist.insert("""
            ```cell_config
            widget-id: \(identity)
            title: Draft
            ```
            ```lua
            return { rows = {} }
            ```
            """, into: &document, target: .init())
        #expect(document.cells[0].widgetID == nil)
        #expect(!document.cells[0].configurationText.contains("widget-id"))
        #expect(document.cells[0].query.title == "Draft")
    }

    @Test(arguments: [
        "", " \n ", "```nrql\nSELECT 1", "```lua\nreturn {}",
        "```graphql\n{ actor { user { name } } }\n```\n```variables\n{}",
        "---\naccounts: [123]", "```cell_config\nvar: incomplete", "Notes\n```swift\nlet x = 1",
        "---\naccounts: [\n---", "```cell_config\nvar: [\n```\n```nrql\nSELECT 1\n```"
    ])
    func invalidDraftDoesNotMutateTheWorkbook(response: String) {
        var document = NRQL_EditorDocument(text: "Original")
        #expect(throws: AIAssist.Failure.self) {
            try AIAssist.insert(response, into: &document, target: .init())
        }
        #expect(document.text == "Original\n")
    }

    @Test func duplicateConfigurationAndMissingInsertionCellDoNotMutateTheWorkbook() {
        var document = NRQL_EditorDocument(text: "---\naccounts: [456]\n---\n\nOriginal")
        let before = document.text
        #expect(throws: AIAssist.Failure.self) {
            try AIAssist.insert("---\naccounts: [123]\n---\n\nDraft", into: &document, target: .init())
        }
        #expect(throws: AIAssist.Failure.self) {
            try AIAssist.insert("Draft", into: &document, target: .init(cellID: UUID()))
        }
        #expect(document.text == before)
    }

    @Test func replacementPreservesCellIdentityOmittedSettingsAndCommentary() throws {
        let widgetID = UUID()
        var document = NRQL_EditorDocument(text: """
            ```cell_config
            # Keep this chart setting
            chart: billboard
            var: traffic
            widget-id: \(widgetID)
            future: retained
            title: Old
            ```
            ```nrql
            SELECT count(*) FROM Transaction
            ```

            ```lua
            return { rows = {} }
            ```
            """)
        let original = document.cells[0]
        let otherID = document.cells[1].id
        let otherText = document.cells[1].text
        let result = try AIAssist.replace("""
            Here is the revised query.

            ```cell_config
            title: Requests per minute
            widget-id: \(UUID())
            ```
            ```nrql
            SELECT rate(count(*), 1 minute) AS rpm FROM Transaction
            ```

            The chart now shows a rate.
            """, in: &document, target: .init(cellID: original.id, originalText: original.text))
        #expect(result == original.id)
        #expect(document.cells.map(\.kind) == [.markdown, .nrql, .markdown, .lua])
        let revised = document.cells[1]
        #expect(revised.id == original.id)
        #expect(revised.query === original.query)
        #expect(revised.query.title == "Requests per minute")
        #expect(revised.widgetID == widgetID)
        #expect(revised.query.resultNames == ["traffic"])
        #expect(revised.configurationText.contains("# Keep this chart setting"))
        #expect(revised.configurationText.contains("chart: billboard"))
        #expect(revised.configurationText.contains("future: retained"))
        #expect(revised.editorText.contains("rate(count(*)"))
        #expect(!revised.isCollapsed)
        #expect(!revised.query.hasResult && !revised.query.isRunning)
        #expect(document.cells[3].id == otherID)
        #expect(document.cells[3].text == otherText)
        #expect(NRQL_EditorDocument(text: document.text).text == document.text)
    }

    @Test(arguments: [false, true])
    func graphqlReplacementKeepsOmittedVariablesAndExtractionBindings(explicitVariables: Bool) throws {
        var document = NRQL_EditorDocument(text: """
            ```cell_config
            var: response
            bindings:
              - name: user
                expression: data.actor.user
            ```
            ```graphql
            query User($id: Int!) { actor { user { name } } }
            ```
            ```variables
            {"id": 123}
            ```
            """)
        let id = document.cells[0].id
        let response = "```graphql\n{ actor { user { name email } } }\n```"
            + (explicitVariables ? "\n```variables\n{}\n```" : "")
        try AIAssist.replace(response, in: &document, target: .init(cellID: id))
        #expect(document.cells.count == 1)
        #expect(document.cells[0].id == id)
        #expect(document.cells[0].query.resultNames == ["response", "user"])
        #expect(document.cells[0].query.variables == (explicitVariables ? "{}" : #"{"id": 123}"#))
        #expect(document.cells[0].editorText.contains("email"))
    }

    @Test(arguments: [(NrqlCellKind.markdown, "# Revised"), (.lua, "return { rows = { { count = 2 } } }")])
    func replacesMarkdownAndScriptsInPlace(kind: NrqlCellKind, code: String) throws {
        var document = NRQL_EditorDocument(text: kind.template)
        if document.cells.isEmpty { document.addCell(kind: kind) }
        let id = document.cells[0].id
        try AIAssist.replace(kind.wrap(code), in: &document, target: .init(cellID: id))
        #expect(document.cells.count == 1)
        #expect(document.cells[0].id == id)
        #expect(document.cells[0].editorText == code)
        #expect(document.focusedCellId == (kind == .markdown ? nil : id))
    }

    @Test func configurationReplacementUpdatesTheSingleFrontmatterAndPreservesOmittedFields() throws {
        var document = NRQL_EditorDocument(text: "---\nauthor: Ada\naccounts: [123]\n---\n\n# Notes")
        let original = document.cells[0]
        let prompt = AIAssist.prompt(request: "Use account 456", document: document, target: .init(cellID: original.id))
        #expect(prompt.contains("Return the revised document configuration"))
        try AIAssist.replace("---\naccounts: [456]\n---", in: &document, target: .init(cellID: original.id))
        #expect(document.cells.map(\.kind) == [.config, .markdown])
        #expect(document.cells[0].id == original.id)
        #expect(document.cells[0].editorText.contains("author: Ada"))
        #expect(try document.connection.get().accountIds == [456])
    }

    @Test(arguments: [
        "", "```nrql\nSELECT 2", "```lua\nreturn {}\n```",
        "```nrql\nSELECT 2\n```\n\n```nrql\nSELECT 3\n```",
        "---\naccounts: [123]\n---\n\n```nrql\nSELECT 2\n```",
        "```cell_config\nvar: [\n```\n```nrql\nSELECT 2\n```"
    ])
    func invalidReplacementDoesNotMutateDocumentOrSharedQuery(response: String) {
        var document = NRQL_EditorDocument(text: "```nrql\nSELECT 1\n```")
        let before = document.text
        let original = document.cells[0]
        let queryText = original.query.text
        do {
            try AIAssist.replace(response, in: &document, target: .init(cellID: original.id))
            Issue.record("Expected invalid replacement to fail")
        } catch {
            #expect(document.text == before)
            #expect(original.query.text == queryText)
        }
    }

    @Test func replacementRejectsStaleOrDeletedTargetsButInsertionStillKeepsConcurrentEdits() throws {
        var document = NRQL_EditorDocument(text: "```nrql\nSELECT 1\n```")
        let original = document.cells[0]
        let target = AIAssist.Target(cellID: original.id, originalText: original.text)
        document.cells[0].editorText = "SELECT 2"
        #expect(throws: AIAssist.Failure.self) {
            try AIAssist.replace("```nrql\nSELECT 3\n```", in: &document, target: target)
        }
        #expect(throws: AIAssist.Failure.self) {
            try AIAssist.replace("```nrql\nSELECT 3\n```", in: &document, target: .init(cellID: UUID()))
        }
        #expect(document.cells[0].editorText == "SELECT 2")
        try AIAssist.insert("```nrql\nSELECT 3\n```", into: &document, target: target)
        #expect(document.cells.map(\.editorText) == ["SELECT 2", "SELECT 3"])
    }

    @MainActor @Test func automaticCellEditUndoesAndRedoesAllCellsAndSharedQuerySourceTogether() throws {
        let widgetID = UUID()
        var document = NRQL_EditorDocument(text: """
            ```cell_config
            var: traffic
            widget-id: \(widgetID)
            chart: billboard
            ```
            ```nrql
            SELECT 1
            ```

            Untouched notes
            """)
        let original = document.cells[0]
        let before = document.text
        let originalIDs = document.cells.map(\.id)
        let manager = UndoManager()
        manager.groupsByEvent = false
        let binding = Binding(get: { document }, set: {
            #expect(!manager.isUndoRegistrationEnabled)
            document = $0
        })
        let id = try AIAssist.apply("""
            Here is the improvement.

            ```cell_config
            var: revised
            chart: table
            ```
            ```nrql
            SELECT 2
            ```

            ```lua
            return { rows = {} }
            ```
            """, to: binding, target: .init(cellID: original.id, originalText: original.text), undoManager: manager)
        let after = document.text
        let generatedIDs = document.cells.map(\.id)
        #expect(id == original.id)
        #expect(document.cells.map(\.kind) == [.markdown, .nrql, .lua, .markdown])
        #expect(original.query.nrql == "SELECT 2")
        #expect(original.query.resultNames == ["revised"])
        #expect(document.cells[1].widgetID == widgetID)
        #expect(manager.undoActionName == "AI Assist")
        for _ in 0..<2 {
            manager.undo()
            #expect(document.text == before)
            #expect(document.cells.map(\.id) == originalIDs)
            #expect(document.cells[0].query === original.query)
            #expect(original.query.text == document.cells[0].text)
            #expect(original.query.nrql == "SELECT 1")
            #expect(original.query.resultNames == ["traffic"])
            #expect(document.cells[0].configurationText.contains("chart: billboard"))
            #expect(document.cells[0].widgetID == widgetID)
            #expect(!manager.canUndo)
            manager.redo()
            #expect(document.text == after)
            #expect(document.cells.map(\.id) == generatedIDs)
            #expect(document.cells[1].query === original.query)
            #expect(original.query.nrql == "SELECT 2")
            #expect(original.query.resultNames == ["revised"])
            #expect(!manager.canRedo)
        }
    }

    @MainActor @Test func automaticDocumentEditUndoesFrontmatterAndAllAppendedCellsInOneStep() throws {
        var document = NRQL_EditorDocument(text: "Original notes")
        let original = document.cells[0]
        let manager = UndoManager()
        manager.groupsByEvent = false
        let binding = Binding(get: { document }, set: { document = $0 })
        try AIAssist.apply("""
            ---
            accounts: [123]
            ---

            New commentary

            ```graphql
            query User($id: Int!) { actor { user { name } } }
            ```
            ```variables
            {"id": 123}
            ```
            """, to: binding, target: .init(isDocument: true), undoManager: manager)
        let after = document.text
        let ids = document.cells.map(\.id)
        #expect(document.cells.map(\.kind) == [.config, .markdown, .markdown, .nerdgraph])
        manager.undo()
        #expect(document.cells.map(\.id) == [original.id])
        #expect(document.cells[0].text == original.text)
        #expect(!manager.canUndo)
        manager.redo()
        #expect(document.text == after)
        #expect(document.cells.map(\.id) == ids)
        #expect(document.cells[3].query.variables == #"{"id": 123}"#)
    }

    @MainActor @Test func failedAutomaticEditsDoNotChangeSourceOrRegisterUndo() {
        var document = NRQL_EditorDocument(text: "```nrql\nSELECT 1\n```")
        let original = document.cells[0]
        let manager = UndoManager()
        manager.groupsByEvent = false
        let binding = Binding(get: { document }, set: { document = $0 })
        for response in ["```nrql\nSELECT 2", "```nrql\nSELECT 2\n```\n\n```nrql\nSELECT 3\n```"] {
            #expect(throws: AIAssist.Failure.self) {
                try AIAssist.apply(response, to: binding, target: .init(cellID: original.id), undoManager: manager)
            }
        }
        #expect(throws: AIAssist.Failure.self) {
            try AIAssist.apply("```nrql\nSELECT 2\n```", to: binding, target: .init(cellID: original.id), undoManager: nil)
        }
        #expect(document.text == original.text + "\n")
        #expect(original.query.text == original.text)
        #expect(!manager.canUndo)
    }

    @Test func directCommandReceivesPromptOnStdinNotAsShellCodeAndDrainsLargeOutput() async throws {
        let prompt = "Quotes ' \" and $(not-a-command); `not-a-command`\n" + String(repeating: "row\n", count: 40_000)
        let result = try await AIAssist.run(command: "/bin/cat", prompt: prompt)
        #expect(result == prompt)
    }

    @Test func commandRunsInHomeDirectoryWithoutAHelper() async throws {
        let result = try await AIAssist.run(command: "/bin/pwd", prompt: "")
        #expect(URL(fileURLWithPath: result.trimmingCharacters(in: .whitespacesAndNewlines))
            .resolvingSymlinksInPath() == FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath())
    }

    @Test func commandSkipsUserStartupFilesAndIncludesStandardExecutableLocations() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = directory.appendingPathComponent("startup-ran")
        for file in [".zshenv", ".zprofile", ".zshrc", ".zlogin"] {
            try "echo startup > '\(marker.path)'\n".write(
                to: directory.appendingPathComponent(file), atomically: true, encoding: .utf8
            )
        }
        let environment = ["ZDOTDIR": directory.path, "PATH": ""]
        #expect(try await AIAssist.run(command: "cat", prompt: "Only the prompt\n", environment: environment) == "Only the prompt\n")
        #expect(!FileManager.default.fileExists(atPath: marker.path))
        let path = try await AIAssist.run(command: #"printf '%s' "$PATH""#, prompt: "", environment: environment)
        let locations = path.split(separator: ":").map(String.init)
        #expect(locations.contains("/opt/homebrew/bin"))
        #expect(locations.contains("/usr/local/bin"))
        #expect(locations.contains(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin").path))
    }

    @MainActor @Test func exampleCommandsPassTheWorkbookPromptWithoutEvaluatingItsContents() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let prompt = "Draft a cell.\nQuotes: ' \" and $(not-a-command); `not-a-command`.\nUnicode: caf\u{00e9}."
        for example in AIAssistPreferencesView.commandExamples {
            let executable = String(example.command.prefix { $0 != " " })
            let stub = directory.appendingPathComponent(executable)
            try """
                #!/bin/sh
                case "$0" in
                  */copilot|*/gemini)
                    while [ "$#" -gt 0 ]; do
                      case "$1" in
                        -p|--prompt) shift; printf '%s' "$1"; exit 0 ;;
                      esac
                      shift
                    done
                    exit 2
                    ;;
                  *) exec /bin/cat ;;
                esac
                """.write(to: stub, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: stub.path)
            let command = "'\(stub.path)'" + example.command.dropFirst(executable.count)
            let result = try await AIAssist.run(command: command, prompt: prompt)
            #expect(result == prompt, "\(example.name) should receive the whole prompt as data")
        }
    }

    @Test(arguments: [
        ("/usr/bin/true", "returned no output"),
        ("printf 'provider failed' >&2; exit 7", "provider failed"),
        ("/nr-status-missing-command", "status 127"),
        ("/usr/bin/head -c 2097153 /dev/zero | /usr/bin/tr '\\000' x", "exceeds 2 MB")
    ])
    func commandFailuresAreActionable(command: String, expected: String) async throws {
        do {
            _ = try await AIAssist.run(command: command, prompt: "request")
            Issue.record("Expected command failure")
        } catch {
            #expect(error.localizedDescription.contains(expected))
        }
    }

    @Test func unconfiguredCommandHasAnActionableError() async {
        do {
            _ = try await AIAssist.run(command: " ", prompt: "")
            Issue.record("Expected configuration failure")
        } catch {
            #expect(error.localizedDescription.contains("Set an AI command"))
        }
    }

    @Test(arguments: [false, true])
    func cancellationStopsRunningCommandsIncludingThoseIgnoringTermination(ignoresTermination: Bool) async throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("ai-process-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: marker) }
        let command = (ignoresTermination ? "trap '' TERM; " : "")
            + "printf '%s' $$ > '\(marker.path)'; exec /bin/sleep 30"
        let task = Task {
            try await AIAssist.run(command: command, prompt: "")
        }
        defer { task.cancel() }
        let pid = try await processID(from: marker)
        let started = ContinuousClock.now
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch {
            #expect(error is CancellationError)
        }
        #expect(started.duration(to: .now) < .seconds(3))
        #expect(Darwin.kill(pid, 0) == -1 && errno == ESRCH)
    }

    @Test func cancellationAlsoStopsPipelineChildren() async throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("ai-child-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: marker) }
        let task = Task {
            try await AIAssist.run(
                command: "/bin/sleep 30 &\nchild=$!\nprintf '%s' \"$child\" > '\(marker.path)'\nwait",
                prompt: ""
            )
        }
        defer { task.cancel() }
        let pid = try await processID(from: marker)
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch {
            #expect(error is CancellationError)
        }
        for _ in 0..<50 {
            if Darwin.kill(pid, 0) == -1 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(Darwin.kill(pid, 0) == -1 && errno == ESRCH)
    }

    @Test func alreadyCancelledRequestDoesNotLaunchTheCommand() async throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("ai-cancelled-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: marker) }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await AIAssist.run(command: "printf started > '\(marker.path)'", prompt: "")
        }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch {
            #expect(error is CancellationError)
        }
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    private func processID(from marker: URL) async throws -> Int32 {
        for _ in 0..<200 {
            if let value = try? String(contentsOf: marker, encoding: .utf8), let pid = Int32(value) {
                return pid
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        throw AIAssist.Failure.message("The command did not start within five seconds.")
    }
}
