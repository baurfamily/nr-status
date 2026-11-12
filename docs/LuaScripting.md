# Phase 7: Lua scripting — design note

Status: draft, for discussion. Nothing implemented yet.

## Goals

1. Build queries from earlier results ("take the top 5 apps from cell 1 and query each one").
2. Loops / repetition without copy-pasting cells.
3. Derived data (joins, ratios, filtering) that NRQL can't express, still charted through the existing pipeline.

Non-goals: general-purpose scripting, file/network access, replacing NRQL as the default mode.

## Where the current code constrains us

- A document is a list of `NrqlCell`s, each owning an `NrqlQuery` (`text`, `nrql`, `format`, `state`). Cells are split on blank lines (`NrqlDocumentParser`), so any new cell kind must survive that round-trip (no blank lines inside a block).
- Results are `NrdbResultContainer` → `NrdbResults.Datum`. Charts, tables and export all consume that type, so a script that emits a result set should produce one too.
- Cells run independently today (`runAllQueries` fires them all). Scripts introduce ordering.

## Proposed syntax

NRQL stays the default. Lua appears in two places only.

**1. Interpolation in a query: `{{ expr }}`**

```
// Slowest apps
FROM Transaction SELECT average(duration) WHERE appName IN ({{ names(results.top_apps) }}) FACET appName
```

Evaluated before the query is sent; the value is converted to a string (tables of strings become `'a', 'b'` for `IN`). The NRQL text shown in the editor is unchanged; the expanded text is shown in the result header.

**2. Script cells: a ` ```lua ` fenced block**

```lua
-- name: top_apps
local r = query("FROM Transaction SELECT count(*) FACET appName LIMIT 5")
emit(r)
```

Fences contain no blank lines (the parser would split them); a blank line inside a script is written as `--`. Script cells render as code plus their emitted result (or `chart: none` to hide it).

### Cell names

A leading `// name: top_apps` comment (NRQL cells) or `-- name:` (Lua cells) names a cell. `results` is a table keyed by both name and 1-based cell index: `results.top_apps`, `results[1]`.

## Lua API (small and explicit)

| Function | Purpose |
|---|---|
| `results.<name>` / `results[i]` | Read-only result of an earlier cell. |
| `query(nrql)` | Run an NRQL string, return a result table. Async on the Swift side; Lua sees a blocking call (coroutine-based). |
| `emit(result)` | Make this cell's result the given table; it flows through the chart pipeline. |
| `names(result)`, `column(result, field)`, `values(...)` | Helpers for building `IN (...)` lists etc. |

Result table shape (mirrors `Datum`):

```lua
{ nrql = "...", columns = {"appName", "count"},
  rows = { {appName = "x", count = 3}, ... },
  facets = {...}, timeseries = true/false }
```

## Embedding

Candidate: `tomsci/LuaSwift` (SPM, wraps C Lua, actively maintained, supports pushing/pulling Swift values and calling into Swift). Alternative: `ChrisGVE/LuaSwift`. Both vendor C Lua, so there is no system dependency. Decision to confirm by a spike (see below).

Sandbox: open only `base` (minus `dofile`, `loadfile`, `require`), `string`, `table`, `math`, `utf8`, `coroutine`. No `io`, `os`, `debug`, `package`. Instruction-count hook (e.g. 10M) and a wall-clock timeout so a runaway loop can't hang the app; memory limit via a custom allocator if the wrapper allows it. Each run uses a fresh `lua_State`.

## Execution model

- Build a dependency graph per document: a cell depends on any `results.<name>`/`results[i]` it references and on queries it requests. Static detection by scanning for `results` accesses is good enough; scripts that compute the key dynamically fall back to "depends on all earlier cells".
- Run order is a topological sort. Run All runs it in dependency order, parallelising independent cells. Running one cell runs its stale dependencies first (opt-out: use last result if present).
- Cycles and references to later cells are errors shown on the cell.
- Cell results are cached by input hash (expanded NRQL / script text + dependency result hashes), so re-runs only redo what changed. `NrqlQuery.id` already hashes the text and can be extended.
- `query()` inside a script must go through the same NerdGraph client and honour cancellation.

## Charting synthetic data

`emit` builds an `NrdbResultContainer` from the Lua table (infer `isTimeseries` from `beginTimeSeconds`, facets from the `facets` list). It is then charted exactly like a query result, including export (PDF/HTML). The format block (`/*** ... ***/`) applies to script cells unchanged.

## UI and editor support

- Script cells use the same `CodeEditor` with Lua highlighting (Highlightr already supports it). No autocomplete in v1 beyond `results` names.
- Errors (syntax, runtime, timeout) show in the cell's result area with the Lua line number.
- Loops: a script can `emit` multiple results; each gets its own chart under the cell (v2 — v1 allows one emit per cell).

## Open questions for you

1. Is `{{ }}` interpolation + fenced script cells the right surface, or do you want only one of them in v1?
2. Should running a cell auto-run its stale dependencies, or require Run All?
3. Must `query()` be allowed inside scripts (powerful, and enables loops), or should scripts only transform existing cell results at first?
4. One result per script cell for v1 — acceptable?
5. Library: OK to add `tomsci/LuaSwift` as an SPM dependency (subject to the spike)?

## Implementation steps (each its own commit)

1. **Spike:** add the package, run `return 1 + 1`, confirm sandboxing and the instruction hook work; pick the library.
2. **LuaRuntime:** sandboxed state, timeout, value bridge (Swift ⇄ Lua tables), tests.
3. **Result bridge:** `NrdbResultContainer` → Lua table and back (`emit`), with tests for faceted/timeseries shapes.
4. **Interpolation:** `{{ }}` expansion in `NrqlQuery` before run; errors surfaced.
5. **Script cells:** parser round-trip for fenced blocks, cell kind, Lua highlighting, UI.
6. **Dependency graph + ordered Run All**, caching.
7. **`query()` from scripts**, cancellation, rate limiting.
8. **Export and docs:** include script cells in text/HTML/PDF export; update `EditorImprovements.md`.
