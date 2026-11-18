# AI Assist

[Documentation](README.md) · [Using the app](UsingTheApp.md)

AI Assist drafts a workbook or improves an existing cell through an AI command
you choose. It is a one-shot writing tool, not a chat interface. No AI provider
is built in.

## Set up your command

1. Install your preferred AI CLI and authenticate in Terminal.
2. Open **Settings > AI Assist**. Enter a noninteractive shell command that
   reads its prompt from **stdin**, writes its answer as UTF-8 text to
   **stdout**, and exits. Send diagnostic messages to **stderr**. A wrapper
   script can adapt tools that use a different input/output convention.

No helper or setup script is required. The directly distributed app runs your
configured command using `/bin/zsh -f -c` in your home directory, with your user
permissions. User shell startup files are not loaded, avoiding unrelated
login-shell commands and their file-access prompts. The inherited `PATH` is
extended with `~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin`, and the
standard macOS executable directories. Use absolute paths or set `PATH` in the
command for other installations, including version-managed runtimes.
Only configure commands you trust. There is no interactive terminal.
Commands and authentication are local to your Mac, not saved in `.nrmd` files.

### macOS folder permissions

AI Assist passes workbook source through stdin; it does not need to browse your
Documents folder. The app does not load your shell profiles just to run an AI
command. However, the configured CLI, its settings, hooks, or extensions may
still try to access protected folders. macOS controls those permission prompts;
the app cannot suppress them or guarantee that an arbitrary command never asks.

If folder access is intentional, macOS normally remembers approval for a
consistently signed, installed app. Check **System Settings > Privacy &
Security > Files & Folders** for NR Status or the tool named in the prompt.
Repeated prompts can occur when switching between app copies, rebuilding
unsigned apps, or changing the tool's identity. Prefer a single, consistently
signed app build; Full Disk Access is not required for AI Assist.

## Example commands

Open **Settings > AI Assist > Command examples** and choose **Use** to fill
the command field, or copy one of these commands. Choosing an example does
not run it. Install and authenticate with the provider's CLI in Terminal first.
These examples use your CLI's configured default model; availability and
charges depend on your provider and plan.

### GitHub Copilot CLI

Sign in with `copilot login`, then use:

```sh
copilot -p "$(cat)" --silent --deny-tool shell --deny-tool write
```

`$(cat)` reads the workbook prompt from stdin and passes it as one quoted
argument. `--silent` suppresses statistics so stdout contains the answer.
The deny rules block shell commands and file-writing tools; other configured
tools may still be available. Run `copilot help` for your installed CLI's
reference.

### Claude Code

Sign in with `claude auth login`, then use:

```sh
claude -p --output-format text --tools "" --strict-mcp-config --no-session-persistence
```

Print mode reads the prompt directly from stdin and returns plain text.
`--tools ""` disables built-in tools, `--strict-mcp-config` skips normally
configured MCP servers, and `--no-session-persistence` avoids saving a
resumable local session. Organization-managed configuration can still apply.
See the [Claude Code CLI reference](https://code.claude.com/docs/en/cli-reference).

### ChatGPT / OpenAI Codex CLI

For OpenAI, install the **Codex CLI** (`codex`), not the ChatGPT desktop app.
Sign in with `codex login`, then use:

```sh
codex exec --skip-git-repo-check --sandbox read-only --ephemeral -
```

The final `-` reads the whole prompt from stdin. `exec` writes the final
answer to stdout and progress to stderr. The Git-check override lets it run
from your home directory without a repository; the agent's sandbox is
explicitly read-only, and `--ephemeral` avoids persisting session rollout
files. Read-only does not mean tools are disabled.
See [Codex non-interactive mode](https://developers.openai.com/codex/noninteractive/).

### Google Gemini CLI

Run `gemini` in Terminal and complete its authentication flow, then use:

```sh
gemini --approval-mode default --output-format text --prompt "$(cat)"
```

The quoted prompt selects noninteractive mode; text output avoids a JSON
envelope. Default approval mode does not blanket-approve tool use.
See the [Gemini CLI reference](https://geminicli.com/docs/cli/cli-reference/).

### Notes

These are starting points, not a security boundary: each CLI can load its own
settings, hooks, instructions, or extensions. No blanket approval or
permission-bypass flags are needed to draft workbook text.
Do not select JSON or streaming-JSON output: AI Assist expects the answer
itself, not an event stream.

If a command is not found, run `command -v copilot` (or `claude`, `codex`,
`gemini`) in Terminal and replace that executable name with its full path.
For paths containing spaces, quote the executable path.
CLI flags can change; consult the installed tool's `--help` if it rejects an
option. The Copilot and Gemini examples put the prompt in a command-line
argument, so very large workbooks can hit macOS argument-size limits.

## Local connection check

For a local smoke check without contacting an AI service, temporarily use:

```sh
cat >/dev/null; printf '# AI Assist is connected\n'
```

This consumes the prompt and returns a Markdown heading. Replace it with your
AI command afterward.

## Draft a document or improve a cell

The two entry points have distinct roles:

- **AI Assist** in the document toolbar opens **Help Write a Document**
  directly. It drafts cells for the workbook and appends them.
  Start with a new workbook and delete its starter query if you want only the
  generated content.
- The small **sparkles button in each cell's header** opens **Write or Improve
  Cell** for that specific cell, whether or not its editor has focus. It asks
  for one revised cell of the same kind, with optional Markdown explanation.

Both include the current workbook source as context. Describe what you want
and choose **Generate**. Expand the prompt disclosure to inspect the exact
format instructions and context before sending. Valid output applies
automatically and closes the sheet:

- A **document draft** appends the new content.
- A **cell draft** replaces the targeted cell, keeping its identity. Omitted
  cell settings and GraphQL input variables are retained; settings explicitly
  included in the draft override their existing values. Commentary and
  additional cells of other kinds are inserted in the returned order.

There is no extra replace/insert decision or acceptance click. Choose
**Edit > Undo AI Assist** (**Command-Z**) to revert the entire operation,
including all added cells and settings changes. Redo restores the entire draft.
Undo affects the workbook, not external actions taken by the configured CLI.

If the output is malformed or the replacement is ambiguous, nothing is changed.
The sheet keeps the response in an editable preview with an explanation.
Correct it and choose **Apply Draft**, or cancel. If the original cell changed
while the command was running, replacement is blocked; copy the draft and
reopen AI Assist with the latest source rather than overwriting those edits.
There is no conversation history.

The prompt briefly describes `.nrmd` fences, configuration, bindings,
interpolation, result shapes, and Lua's role. Existing workbook source supplies
the current variable names and cell definitions. Responses use the normal
workbook parser: prose becomes rendered Markdown, and fenced NRQL, Lua, and
GraphQL become editable cells. `cell_config` and GraphQL `variables` stay with
their cells. Unknown fences remain Markdown.

Generated queries/scripts never run automatically. Review them before running
them, especially GraphQL operations that might modify data. Replacement
requires exactly one cell matching the original kind; surrounding commentary
is kept as Markdown. Additional cells of other kinds are allowed, but multiple
cells of the target's kind require correction in the preview so the replacement
is unambiguous. A replacement keeps the original published widget identity;
generated identities are removed from new cells.

A document draft's new frontmatter block goes at the top; if the workbook
already has one, remove generated frontmatter before inserting. The
configuration cell's own AI button can revise the existing frontmatter via
automatic replacement, preserving omitted configuration fields. Other cell
replacements cannot add document frontmatter. Incomplete code or Markdown
fences must be closed before applying a draft.

## Data and execution

**Generate sends your request and the entire current workbook source** to your
command and whatever AI service it uses. This includes literal document
bindings, account IDs, comments, and anything sensitive you typed into source.
Cached query results and API key secrets from Keychain are not included.
The app does not fetch data or run cells to prepare the prompt.

Prompts and output use private temporary files, removed when the command
finishes; they are not saved as chat history. The external CLI or its provider
may retain data according to its own configuration. Responses are limited to
2 MB, and a failed command's stderr is shown in the prompt sheet.

**Cancel** stops the command and its process group, discards the response, and
removes the temporary files once the process exits. Commands that do not stop
on termination are force-stopped after one second. A tool that deliberately
detaches its own background processes may leave those running separately.
