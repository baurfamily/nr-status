# Editor Improvements (branch: `editor-improvements`)

## Requirements summary

### Pre-note
Decide whether the current editor library (`CodeEditorView`, with `CodeEditor`/`Highlightr`/`Rearrange` also in the package graph) is the right one, or whether to switch to `CodeEditSourceEditor`, or something else.

### High level
1. **Notebook / workbench editor**: multiple queries in one document; Cmd-Return with the cursor in a query runs it.
2. **Inline results**: chart/table renders below its query and is collapsible.
3. **Autocomplete**: NRQL keywords and functions, event types and attributes. Prefer metadata from NerdGraph/NRQL (e.g. `SHOW EVENT TYPES`, `keyset()`, NerdGraph schema/introspection) over hard-coded lists.

### More complex
4. **Formatting doc-comments** controlling the visualization, e.g.
   ```
   /***
   chart: line
   attributes: smoothed, lines, points
   ***/
   ```

### Way more complex
5. **Lua scripting**: query results accessible from Lua and substitutable into later queries, e.g.
   ```
   FROM Transaction SELECT count(*) FACET appName
   FROM Transaction SELECT average(duration) WHERE appName = {{results[1]["appName"]}}
   ```
   Open design questions:
   - Interpolation style: `{{code}}`, `\(code)`, or Ruby-like.
   - Mode detection: NRQL by default with Lua only in comments/interpolations, vs. Lua by default with a function/sigil to run NRQL, vs. Razor-style.
   - Loops that produce multiple charts.
   - Suppressing charts for intermediate queries.
   - Charting data constructed/merged in Lua.

### Exporting
6. PDF, HTML, NRQL "text".

### Nice to have
7. Vim-style navigation (nvim integration like VS, or Xcode-style emulation).
8. AI-assisted query (or script) authoring.

## Current state (as of branch creation)
- `DocumentView` uses `CodeEditorView`'s `CodeEditor`; `NRQL_EditorDocument` (`FileDocument`) stores `CodeEditor.Position` and maps cursor -> `DocumentQuery` via `queryAt`.
- `NrqlDocumentParser` splits text into `ParsedQuery`s; `NrqlLanguageSupport` provides a `LanguageSupport` NRQL configuration (tokenizer only).
- Results shown in a separate `ResultsTabView`, not inline.
- Chart rendering/config already exists in `NR Models/Display` (`ChartSelector`, `ConfigurableChartView`, `ChartConfiguration`, ...), reusable for inline results.

## Design decision: single file, derived cells
- One plain-text NR Markdown file (e.g. `myQueries.nrmd`) is the source of truth; cells are a *view* over it. The parser splits the text into cells where each new query begins (doc-comment blocks attach to the query below). Cell edits are written back into that slice of the text.
- In the file: query text, doc-comments, and later Lua blocks / `{{ }}` interpolations. Not in the file: results, run state, collapsed state (transient, or sidecar/`FileDocument` metadata if persisted).
- Works without scripting: a plain-NRQL document gets inline results and Cmd-Return too. Lua only adds new segment types; cell dependencies (`results[1]`) are derived from text references.
- Open question (decide in Phase 1): boundary detection. Default blank-line separation is ambiguous for queries containing blank lines; add an explicit delimiter (`;` or a doc-comment) as override.
- Resolved in Phase 0: one editor per cell (easy embedding; undo/cursor are per cell, and the model joins cells back into the file text).

## Plan

Each phase should be shippable on its own and keep tests green (`NrqlDocumentTests`, `QueryBuilderTests`, ...).

### Phase 0: Editor library decision (DONE)
**Decision: keep `CodeEditorView` (0.15.3), one editor instance per cell, file text as source of truth.**
Findings: it has a completion API (`LanguageService`, `Completions`) and inline message views, but no way to embed arbitrary SwiftUI views in the text flow, so inline results come from the cell stack, not the editor. `CodeEditSourceEditor` would not change that, is macOS-only, and has no NRQL grammar. Revisit only if per-cell undo/cursor movement proves too limiting.
Original evaluation notes:
Evaluate against these criteria: inline block/view embedding below a text range (the key need), custom completion providers, text attributes/decorations, multi-cursor/vim hooks, macOS-only vs. cross-platform, maintenance health, SwiftUI integration.
- **CodeEditorView (keep)**: has completions and a message/inline-annotation system, but no arbitrary SwiftUI views embedded in the text flow.
- **CodeEditSourceEditor**: tree-sitter highlighting, macOS only, no NRQL grammar (would need one), also no native inline views.
- **Alternative: notebook-style document model** (own it): a vertical list of *cells* (one editor per query + result view beneath). Inline results become trivial (SwiftUI stack), collapse is just state, and any editor library only needs to edit a single cell. This is the likely winner; the library then matters mainly for highlighting/completion per cell.
- Deliverable: short decision note appended here, plus a throwaway prototype of one cell (editor + result).

### Phase 1: Document model and parser
- Define `Cell` model (query text, optional doc-comment config, id, result state, collapsed flag), keeping the plain-text file format round-trippable (queries separated as `NrqlDocumentParser` does today).
- Extend `NrqlDocumentParser` to produce cells with source ranges and to recognize `/*** ... ***/` blocks. Unit tests for parsing/round-trip.

### Phase 2: Notebook UI + run
- Cell list view; Cmd-Return runs the focused cell (menu command + `keyboardShortcut`); Shift-Return/"Run all" optional.
- Per-cell run state (idle/running/error/result) via async/await (no Combine).

### Phase 3: Inline, collapsible results
- Reuse `ChartSelector`/`ConfigurableChartView` below each cell; disclosure toggle; persist collapsed state.
- Replace `ResultsTabView` usage.

### Phase 4: Doc-comment formatting (DONE, one-way)
- `/***` block with `title:` (overrides a `// Title` comment), `chart:` (`chart: none` hides the chart), `var:` and `attributes:` (names separated by spaces and/or commas; listed = on, unlisted = off, only for the active chart type; no `attributes` key = defaults). Lines/points: if neither is listed, lines is forced on.
- Attributes: line `stacked, smoothed, lines, points`; pie `donut, separated`; bar `pivot`; plot `color-facets, x-log, y-log`; billboard `gauge`.
- Facet selection deliberately not supported (better done in the query); could later be auto-added to the query.
- Not done: writing UI changes back into the comment.
- Parse `key: value` bodies (`type`, `attributes`, ...) into `ChartConfiguration`; apply on render.
- Write back when chart config is changed in the UI (bidirectional, optional).
- Tests for parsing and mapping to chart types.

### Phase 5: Autocomplete (DONE, no function signatures yet)
- `NrqlCompletion` analyses the cell text around the cursor (after `FROM` → event types; `SELECT`/`WHERE`/`FACET` → attributes of the `FROM` event, functions and clause keywords; inside a `/***` block → format keys, chart types and attribute names). Quiet inside comments and strings.
- `NrqlMetadata` caches `SHOW EVENT TYPES` and `keyset()` per session; `NrqlLanguageService` plugs it into the editor (one per cell, completion shows as you type or on the editor's completion shortcut).
- Static NRQL keyword/function list (grammar-level, small and stable).
- Dynamic: event types via NRQL `SHOW EVENT TYPES`; attributes via `keyset()` (or `SELECT keyset() FROM X`) with caching per account/event; infer event from the cell's `FROM` clause.
- Investigate NerdGraph for function signatures; if unavailable, a small curated signature table.
- Context-aware completion (after `FROM`, `SELECT`, `WHERE`, `FACET`, ...).

### Phase 6: Export (done: File ▸ Export for NRQL text, HTML and PDF)
- NRQL text (concatenate cells/comments), HTML (queries + rendered charts/tables via `ImageRenderer` or SVG), PDF (`ImageRenderer`/print). Share-sheet/File > Export menu.

### Phase 7: Lua scripting (design first)
- Write a design note resolving the open questions. Suggested starting position: NRQL is the default mode; Lua appears only in `{{ ... }}` interpolation (expressions) and in explicit ```` ```lua ```` script cells; `results` is a table of prior cell results (by index and by optional cell name); cells can be marked `hidden`/`intermediate` via doc-comment (`chart: none`); loops via a script cell that emits multiple derived queries, each rendering its own result.
- Embed Lua (e.g. a Swift Lua package/C Lua), sandbox it (no io/os), bridge results as tables.
- Dependency graph between cells for re-run ordering.
- Charting Lua-built data: allow a script cell to emit a synthetic result set that goes through the same chart pipeline.

### Phase 8: Stretch
- Vim keybindings (evaluate embedding nvim vs. a lightweight modal layer; depends on Phase 0 library choice).
- AI-assisted query/script generation (prompt panel in a cell; supply schema/keyset context; FoundationModels or remote model).

## Suggested order
0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8. Phases 5 and 6 are independent of each other and can be reordered.
