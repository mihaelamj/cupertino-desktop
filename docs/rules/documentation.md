# Documentation Rules (DocC)

How TileKit organizes its documentation: a single DocC catalog that is the source of truth and moves with the code in every PR.

Every project's documentation lives in a **DocC catalog** inside the repo as its own SPM target. There is no freeform `Docs/` folder. The catalog is the single source of truth. Every PR that touches code must update the matching catalog article in the same PR.

## Core rules

### Rule 1: Documentation lives in a DocC catalog

Organize repo-level documentation as a Swift-DocC catalog in a dedicated SPM target.

- MUST create a docs-only SPM target named `{ProductName}Documentation` (Apple's own convention, see `SwiftDocCPluginDocumentation`).
- MUST contain a `.docc` catalog directory inside that target: `{ProductName}Documentation.docc/`.
- MUST have a single minimal Swift source file in the target (DocC requires at least one Swift file). Typical content: `@_exported import Foundation` with a comment explaining the target's purpose.
- MUST have `swift-docc-plugin` listed as a package dependency in `Package.swift` (from 1.4.3 or newer).
- MUST use `@DisplayName("ShortName")` on the landing page to give readers a short sidebar label while the target keeps the long, unambiguous name (e.g. target `TileKitDocumentation`, display name `TileKit`).
- MUST NOT add `@TechnologyRoot` to the landing page; DocC warns it is unnecessary for a landing page tied to a module.

### Rule 2: Never keep a `Docs/` folder alongside the catalog

Never let documentation accumulate in a freeform `Docs/` directory.

- MUST consolidate all project-level prose into the catalog.
- MUST delete any legacy `Docs/` folder during DocC adoption.
- MUST migrate each `.md` file to a PascalCase article inside `{Name}.docc/`.
- MAY keep package-level `README.md` files next to code (they serve different audiences; the catalog cross-references them as plain text paths when needed).

### Rule 3: Landing page is an Apple-style sample-article

Model the catalog landing page (`{Name}.md`) on Apple's sample-article format (e.g. the Wishlist or Landmarks sample).

**MUST have:**
- First line: `# ``{TargetName}``` (the `<doc:>`-resolving backtick form).
- `@Metadata { @DisplayName("...") }` block.
- One-sentence abstract right under the title.
- `## Overview` with 2 to 3 paragraphs of context.
- `## Configure the sample code project` with clone, build, run steps.
- One or more `## {feature area}` sections, each with prose + a real code listing + optionally a diagram.
- A closing `## Topics` section that groups every article in the catalog.

**MUST NOT have:**
- Marketing filler ("that's it!", "only N lines", "super simple", "production-ready" status badges).
- Aspirational content; everything in the landing page is accurate to current repo state.

### Rule 4: Topics structure: flat-wider, not deep

For article-heavy catalogs (not symbol-heavy frameworks), **prefer a flat-wider Topics layout** over multi-level parent articles. Apple uses flat-wider for sample catalogs.

- SHOULD have 5 to 10 top-level Topics groups (guidance, not a hard cap; a 3-group catalog is fine if the groups are cohesive).
- SHOULD have 2 to 8 articles per group.
- MUST avoid 1-item groups (merge the lonely article into an adjacent larger group).
- MUST avoid parent articles that duplicate the landing page's overview (extra click, no new information).
- MAY introduce parent articles ONLY when a category has 8+ items AND they naturally sub-group (e.g. by role or layer).

Apple's framework docs nest via *symbols* (types contain methods); article catalogs stay flat.

### Rule 5: Article format

Every article (`.md` file in the catalog) follows this shape:

```markdown
# Article title in plain language

One-sentence abstract.

## Overview

Two or three paragraphs. Establish context.

## {First topic}

Content with real code listings, tables, lists.

## {Next topic}

...
```

- MUST start with `# Title` (not `# ``Symbol```).
- MUST have an abstract after the title (DocC displays it under the title in the viewer).
- MUST use PascalCase file names (`PackageLayers.md`, not `package-layers.md`).
- MUST match the filename to the `<doc:X>` reference name exactly; DocC is case-sensitive.

### Rule 6: Cross-linking

- MUST use `<doc:ArticleName>` for catalog-internal links. No angle brackets around spaces ever (causes DocC warnings).
- MUST use plain markdown paths (`Packages/Sources/Foo/README.md`) for files outside the catalog.
- MUST NOT use `<doc:>` for non-existent articles; DocC emits a warning per broken reference.
- MUST NOT put `<doc:ExampleName>` inside example code blocks; DocC sometimes tries to resolve them even inside fences. Use `{example-placeholder}` or HTML entities for placeholders.

### Rule 7: Diagrams pipeline: mermaid source, PNG output

Single source of truth is a `.mmd` file; the committed PNG is a generated artifact.

- MUST place `.mmd` sources in `{Name}.docc/Resources/diagrams/`.
- MUST commit the rendered `.png` alongside the source so the catalog renders without Node at read time.
- MUST provide a helper script that runs `npx -y @mermaid-js/mermaid-cli` to regenerate every PNG.
- MUST reference the PNG by filename-without-extension: `![alt](diagram-name)`.

Why PNG: DocC does not render mermaid source. Why commit the PNG: readers without Node still see the diagram; web UIs render it inline.

### Rule 8: Maintainer contract: docs update with every PR

**The documentation catalog is the single source of truth. Every PR that changes code MUST include a matching catalog update in the same PR. No exceptions.**

The catalog MUST include a `MaintainingTheDocs.md` article with an explicit "if you change X, update Y" table.

**Table schema (required columns, in this order):**

| Change | Update | Reviewer check |
|---|---|---|
| (code change, concrete and specific) | (catalog article name + section) | (what a reviewer must verify before approving) |

- "Change" is a concrete trigger, not a category (e.g. "Add a new `ServerEnvironment` case", not "environment changes").
- "Update" names the exact article and section (e.g. "`Environments.md` -> `## Available environments`").
- "Reviewer check" is one sentence, verifiable without running the code (e.g. "New case appears in the table and has a 1-line description").

**MUST cover at minimum** (the table rows):

- Adding/removing a SPM package
- Renaming a public type or module
- Adding/changing a facade or admin endpoint
- Bumping a spec or schema version
- Changing auth mode or session mechanism
- Adding an environment case or scheme variant
- Adding a brand-namespaced component
- Touching the log panel / observability
- Changing offline / caching behavior
- Touching the CI pipeline
- Adding a diagram

Reviewers MUST block approval when code drifts from docs. If the column "Update" is empty for a code change, either the article does not cover it yet (add it) or the change is not doc-relevant (rare; document the judgment call in the PR description).

### Rule 9: Building and previewing

Build from CLI:

```bash
cd Packages
swift package generate-documentation --target {Name}Documentation
```

Preview in browser (live reload on file save):

```bash
swift package --disable-sandbox preview-documentation --target {Name}Documentation --port 8765
```

**Default port 8080 collides with common dev servers** (Vapor, Node, etc.). Always pass `--port 8765` (or any free port).

Open built archive in Xcode:

```bash
open -a Xcode .build/plugins/Swift-DocC/outputs/{Name}Documentation.doccarchive
```

`-a Xcode` is required if Dash (Kapeli) is installed; macOS otherwise hands `.doccarchive` files to Dash.

### Rule 10: Zero warnings is the bar

**MUST NOT commit documentation changes if `swift package generate-documentation` emits any warnings.**

The only tolerated warnings are SPM-level "dependency is not used" notices with this exact shape:

- `warning: 'PackageName': dependency '<dep>' is not used by any target`
- `warning: dependency '<dep>' is not used by any target`

All DocC-emitted warnings (anything from `docc`, anything referencing an article, symbol, resource, or link) MUST be fixed before commit. If a warning appears that does not match the tolerated shape above, treat it as a blocker.

Common fixable warnings:

- `` 'SomeName' doesn't exist at '/...' ``: `<doc:SomeName>` points at an article that does not exist. Fix the name or create the article.
- `Resource 'foo.png' couldn't be found`: image referenced but not in `Resources/`. Move or rename.
- `' ' doesn't exist`: DocC parsed a malformed `<...>` pattern as a symbol reference. Usually caused by `<Placeholder>` in an example block; switch to `{placeholder}` or HTML-escape the angle brackets.

### Rule 11: No private or user-specific references in the catalog

**MUST NOT** reference private / user-specific paths or repos inside the catalog.

- No private-org paths.
- No absolute paths like `/Users/*` or `/Volumes/*`.
- No private helper script names.
- No internal-only chat handles, internal URLs, or credential-adjacent details.

When referencing an upstream backend you do not control, describe the contract abstractly. The reader is a colleague on the shared repo, not a private-notes reader.

### Rule 12: No marketing tone

Technical documentation. Neutral, factual voice.

**MUST NOT:**
- "That's it!", "Just works!" (as filler), "Super simple", "Even easier", "Absolute simplest"
- "Only N lines of code" (as a boast)
- "Production-ready" / status badges
- Excessive checkmark glyphs in prose (DO/DON'T blocks are fine)
- Exclamation marks in section headings

**OK:**
- "No `@Environment(\.colorScheme)` needed": factual statement about built-in behavior
- "Just works" when describing a concrete SwiftUI built-in that does auto-adapt
- Short code comments that state fact (not celebrate)

### Rule 13: Renames, moves, and deletions

When an article is renamed, moved, or deleted, inbound `<doc:>` references break silently at build time (Rule 10 catches them, but only if CI runs DocC). The PR that renames is responsible for fixing every inbound reference in the same commit.

**MUST:**
- Grep the catalog for the old basename before renaming: `grep -rn 'doc:OldName' {Name}Documentation.docc/`.
- Update every hit in the same PR. No stub articles, no redirect shims. DocC does not support redirects, so a stub just duplicates content.
- When deleting an article, remove it from the landing page `## Topics` section in the same commit.

**MUST NOT:**
- Leave a placeholder article with a "moved to X" pointer. Readers see an empty page; cross-refs still break.
- Rely on a follow-up PR to "clean up" broken links. Rule 10 means the build stays green only when the rename is complete.

For renamed public Swift symbols, the catalog article describing that symbol MUST be renamed in the same PR and its filename updated to match the new symbol name (DocC's `<doc:SymbolName>` is case-sensitive and exact).

### Rule 14: Symbol-level `///` comments update with public API changes

Rule 8 covers catalog articles; this rule covers the `///` doc comments attached to declarations in Swift source. Both must move in the same PR as the code change.

**MUST:**
- Add a `///` doc paragraph when introducing any new `public` type, protocol, enum, actor, method, property, or init. The paragraph explains *why* the declaration exists and any non-obvious behaviour (error branches, actor isolation, side effects, invariants), not a restatement of the signature.
- Revise the `///` in the same commit that changes the semantics of a documented public declaration. Signature-only refactors (renames, parameter reorder) count.
- Delete `///` text that no longer reflects behaviour. Stale docs are worse than missing docs because readers trust them.
- Before deleting a `public` symbol, grep the catalog and the source tree for `` ``SymbolName`` `` references and remove or update each one in the same PR.

**MAY skip documenting:**
- `var body` on SwiftUI `View` conformances (Apple's own frameworks do not doc it).
- Protocol-default conformance methods where the protocol itself is fully documented (`init(data:)` + `make()` on `Component` implementations, `init(from:)` / `encode(to:)` for `Codable`, forwarders on a mock).
- Data-struct fields whose name IS the documentation (`title: String`, `firstName: String`). "The title" adds no information.
- `Content: View` inner structs that are implementation detail of a documented component.

**Reviewer check:**
- Any new `public` decl without a `///` paragraph blocks approval (unless it fits a MAY-skip category above; the PR description calls out the skip).
- Any semantic change to a documented public method without a corresponding `///` edit blocks approval.
- Any deletion of a `public` symbol without a matching sweep of `` ``SymbolName`` `` references in the catalog blocks approval.

**Weighting (how much doc is enough):**
- Types & entry points: one-paragraph abstract + non-obvious-behaviour notes. Always.
- Widely-referenced methods (3 or more caller files outside the declaring package): one-line summary + `- Parameter` / `- Returns` / `- Throws` where non-trivial.
- Leaf / single-caller methods: one-line summary only.

A weighted audit (undocumented public decls times cross-package usage) should be run before every major release to catch drift. Items referenced in many files but lacking docs are the highest-value gaps; items referenced nowhere outside their file are near-zero priority.

---

## Verification checklist

Before shipping a docs change:

- [ ] `swift package generate-documentation --target {Name}Documentation` produces zero warnings (excluding generic "dependency is not used").
- [ ] Every article referenced in a `<doc:X>` link exists as a file with that exact basename.
- [ ] Every image referenced as `![alt](name)` exists under `Resources/`.
- [ ] Landing page `## Topics` section lists every article, each in exactly one group.
- [ ] No article references a deleted `Docs/` folder or other legacy paths.
- [ ] No private or user-specific references leaked (`/Users/`, `/Volumes/`, etc.).
- [ ] `Product -> Build Documentation` in Xcode shows the updated content after building.
- [ ] Archive opens in Xcode's Developer Documentation window under "Imported Documentation".
- [ ] Every new/changed `public` declaration has a matching `///` comment in the same PR (or a justified MAY-skip per Rule 14).

## References

- [DocC overview (swift.org)](https://www.swift.org/documentation/docc/)
- [swift-docc-plugin](https://github.com/swiftlang/swift-docc-plugin)
- [Adding structure to your documentation pages (Apple)](https://developer.apple.com/documentation/xcode/adding-structure-to-your-documentation-pages)
- [Writing symbol documentation (Apple)](https://developer.apple.com/documentation/xcode/writing-symbol-documentation-in-your-source-files)
- Apple sample catalogs: Wishlist, Backyard Birds, SlothCreator, Landmarks (check their `.docc` directories in the public sample repos)
