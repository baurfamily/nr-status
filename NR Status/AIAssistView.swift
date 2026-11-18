import SwiftUI

struct AIAssistPreferencesView: View {
    @AppStorage(AIAssist.commandKey) private var command = ""

    static let commandExamples: [(name: String, command: String)] = [
        ("GitHub Copilot", #"copilot -p "$(cat)" --silent --deny-tool shell --deny-tool write"#),
        ("Claude Code", #"claude -p --output-format text --tools "" --strict-mcp-config --no-session-persistence"#),
        ("ChatGPT / OpenAI Codex", "codex exec --skip-git-repo-check --sandbox read-only --ephemeral -"),
        ("Google Gemini", #"gemini --approval-mode default --output-format text --prompt "$(cat)""#)
    ]

    var body: some View {
        ScrollView {
            Form {
                TextField("AI command", text: $command, axis: .vertical)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(2...5)
                    .accessibilityIdentifier("ai-assist-command")
                Text("Enter a noninteractive command that reads the prompt from standard input and writes only its UTF-8 answer to standard output. Standard Homebrew and ~/.local/bin locations are included in PATH; use an absolute path or set PATH in the command for other installations. Authenticate with your AI tool in Terminal first.")
                    .font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Command examples") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Self.commandExamples, id: \.name) { example in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(example.name).fontWeight(.medium)
                                    Spacer()
                                    Button("Use") { command = example.command }
                                        .accessibilityLabel("Use \(example.name) command")
                                        .help("Fill the command field without running it")
                                }
                                Text(example.command)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Text("Install and sign in to the chosen CLI first. OpenAI uses the Codex CLI, not the ChatGPT desktop app. These examples use your CLI's default model and do not grant blanket tool permissions; your CLI settings, hooks and extensions still apply.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                Text("The command runs through /bin/zsh -f -c in your home directory, without loading your shell startup files. This avoids unrelated startup commands and permission prompts; the AI tool can still request file access itself. Only use a command you trust. It is not stored in workbooks.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("AI Assist sends your request and workbook source, including literal bindings, to this command and any service it uses. Cached query results and Keychain secrets are not included. Review sensitive source before generating.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

struct AIAssistSheet: View {
    @Binding var document: NRQL_EditorDocument
    let target: AIAssist.Target
    let onApply: (String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings
    @AppStorage("preferencesTab") private var selectedSettingsTab = "accounts"
    @AppStorage(AIAssist.commandKey) private var command = ""
    @State private var request = ""
    @State private var response: String?
    @State private var errorMessage: String?
    @State private var isRunning = false
    @State private var generation: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(target.isDocument ? "Help Write a Document" : "Write or Improve Cell")
                .font(.title2)
            Text(target.isDocument
                 ? "Generated cells are added automatically. Existing content is kept. Undo reverts the entire AI edit."
                 : "A valid draft replaces this cell automatically. Commentary is kept as Markdown. Undo reverts the entire AI edit.")
                .foregroundStyle(.secondary)
            if response == nil {
                Text("What would you like to write?")
                TextEditor(text: $request)
                    .font(.body)
                    .frame(minHeight: 120)
                    .border(.secondary.opacity(0.3))
                    .disabled(isRunning)
                    .accessibilityIdentifier("ai-assist-request")
                DisclosureGroup("Prompt and workbook context sent to the command") {
                    ScrollView {
                        Text(AIAssist.prompt(request: request, document: document, target: target))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                }
            } else {
                Text("The draft could not be applied automatically. Edit it below and choose Apply Draft, or cancel to leave the workbook unchanged.")
                    .font(.caption).foregroundStyle(.secondary)
                TextEditor(text: Binding(get: { response ?? "" }, set: { response = $0 }))
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 260)
                    .border(.secondary.opacity(0.3))
                    .accessibilityIdentifier("ai-assist-response")
            }
            Text("Your request and workbook source (including literal bindings) are shared with the configured command and its AI service. No cached results or Keychain secrets are sent.")
                .font(.caption).foregroundStyle(.secondary)
            if let errorMessage {
                ScrollView {
                    Text(errorMessage).foregroundStyle(.red).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("ai-assist-error")
                }
                .frame(maxHeight: 90)
            }
            if isRunning {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Waiting for the AI command…")
                }
                Text("Canceling stops the running command and discards the response.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("AI Settings…") {
                    selectedSettingsTab = "ai"
                    openSettings()
                }
                Spacer()
                Button("Cancel", role: .cancel) {
                    generation?.cancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                if let response {
                    Button("Apply Draft") { accept(response) }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Generate") { generate() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(isRunning || request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Configure your command in Settings > AI Assist to get started.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 680)
        .onDisappear { generation?.cancel() }
    }

    private func accept(_ response: String) {
        do {
            try onApply(response)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    private func generate() {
        errorMessage = nil
        isRunning = true
        let prompt = AIAssist.prompt(request: request, document: document, target: target)
        let command = command
        generation = Task { @MainActor in
            defer { isRunning = false }
            do {
                let result = try await AIAssist.run(command: command, prompt: prompt)
                try Task.checkCancellation()
                let draft = AIAssist.responseSource(result)
                response = draft
                accept(draft)
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
        }
    }
}
