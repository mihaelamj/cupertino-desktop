# ca capability request: list children on demand (#49/#50)

**Status:** Draft for coordination with the cupertino agent (ca).
**Date:** 2026-06-08.
**Related:** [large-hierarchy-navigation.md](large-hierarchy-navigation.md); issues #49, #50.
**Not required for:** #51 (search results grouping is client-side over existing `searchDocs` hits).

## Problem

The desktop app can list frameworks (`list-frameworks`) and search/read documents, but
selecting a framework today runs a scoped search with `limit: 1` for a single overview
doc. There is no **children-on-demand** primitive for navigating
`framework -> topics -> symbols -> members`.

## Requested capability

**Name (proposal):** `list-children` (CLI) / MCP tool `list_children`

**Input:**

- `parent_uri: string` (e.g. `apple-docs://swiftui` or a symbol URI), **or**
- `framework: string` plus optional `path: [string]` for shallow roots
- Optional `limit`, `cursor` for pagination

**Output:** array of child nodes:

```json
{
  "id": "apple-docs://swiftui/view",
  "title": "View",
  "kind": "symbol",
  "has_children": true,
  "document_count": 0,
  "uri": "apple-docs://swiftui/view"
}
```

(`kind` is one of `symbol`, `collection`, `article`, or similar stable enum.)

**Semantics:**

- Idempotent read of indexed hierarchy (not a search).
- Empty children means leaf (open via existing `read`).
- Stable `id` suitable for client-side DOI/focus state and diffable snapshots.

## How cda would use it

- Client holds focus node plus DOI threshold ([large-hierarchy-navigation.md](large-hierarchy-navigation.md)).
- On expand or focus change: call `list_children` for the visible frontier only.
- DOI elision stays in `Feature.*` view models; ca supplies graph edges, not presentation.

## Open questions for ca

- Is hierarchy already in the index, or derived from doc metadata?
- Best URI scheme for non-doc container nodes?
- Pagination strategy for wide symbol lists (e.g. Kernel-scale)?
