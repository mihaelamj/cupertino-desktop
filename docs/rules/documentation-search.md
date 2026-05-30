# Using the cupertino documentation index

cupertino is a full-text search (FTS-SQLite) index over Apple's developer
documentation, the Human Interface Guidelines, Swift Evolution, sample code, and
Swift.org, exposed over MCP. It is a **smart query engine, not an intelligent
agent.** It returns ranked documents for a query; it does not reason, explain,
design, compare options, or hold a conversation.

## The rule

For any Apple-platform API question, **search the index and read the results.** Do
not ask cupertino to answer a question, and do not invent API facts from memory
when the index can settle them.

- Query with **keywords**, the way you would type into a search box
  (`NavigationSplitView`, `UISplitViewController column style`,
  `horizontalSizeClass`), not as a prose question. The text is matched, not
  understood; expect documents back, not an answer.
- Read the hits with `mcp__cupertino__read_document` (markdown or json) before you
  rely on a behaviour. Cite what you read, not what you remember.
- Narrow with `source` and `framework` when you know them: `source: apple-docs`
  for modern APIs, `source: hig` for interface guidance, `source: samples` for
  working code, `source: apple-archive` for foundational or legacy topics (Core
  Animation, Quartz 2D, KVO/KVC), `source: swift-evolution` for language history.
- This is the dogfooding path: this app is a native GUI over exactly this index,
  so grounding our own Apple-API decisions in it is both correct and on-brand.

## What it is not

cupertino does not plan, summarise on request, weigh trade-offs, or make decisions.
A returned document is evidence for **you** to read and reason over; the
intelligence is the caller's, the index only retrieves. Treating it as an agent
(asking it "how should I…") is a category error and gets you nothing useful.
