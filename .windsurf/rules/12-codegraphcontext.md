---
trigger: model_decision
description: Pull when navigating iNiR codebase structure, locating authoritative files, mapping dependents (blast radius), or finding existing patterns before edits.
---

# Repo Intelligence — iNiR (How to navigate safely)

## Role in this repo

Use repo-intelligence tools to **narrow the search space** and to produce evidence (authoritative file + dependents) before editing.

In this workspace, prefer:

- `inir-mcp`:
  - `mcp7_search_codebase` (semantic-ish index over paths/symbols)
  - `mcp7_find_examples` (grep-like examples with context)
  - `mcp7_get_blast_radius` (risk + dependents)
  - `mcp7_get_dependency_graph` (imports + reverse)
  - `mcp7_get_file_context` (purpose + symbols + who uses it)
  - `mcp7_get_config_schema` (config keys overview)
- `inir-docs`:
  - `mcp6_search_docs` / `mcp6_read_doc` for steering/mandatory rules

Fallbacks (when MCP isn’t enough):

- `code_search` for targeted cross-repo exploration
- `grep_search` for precise string/regex matching

## Preferred tool order

1. `mcp7_search_codebase` (find the file/symbol candidates)
2. `mcp7_get_file_context` for the top candidates (confirm authoritative)
3. `mcp7_get_blast_radius` or `mcp7_get_dependency_graph` (confirm impact)
4. `mcp7_find_examples` (copy established patterns)
5. Read the real file(s) (`mcp7_read_file` or `read_file`) before editing

## Query discipline

- Prefer **exact identifiers** (component names, singleton names, IPC target names) over broad natural-language.
- Constrain searches by module (`modules/…`, `services/…`) when possible.
- When results conflict with source, trust the source.

## Reindexing

If codebase indexing is stale (search misses obvious symbols), use `mcp7_postchange_audit` after edits to keep the index updated.
