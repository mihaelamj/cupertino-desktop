# Folder Grouping Rule

How to lay out source trees in TileKit: one folder per SPM target, with file-grouping rules for the files inside a target.

Cross-cutting layout rule. Most concrete in Swift / SPM packages where one-target-per-folder is the default; the same intent applies to Python packages, web project trees, docs trees, anywhere a tree of files exists.

## SPM targets: one folder per target is the MANDATE (not just the default)

For SwiftPM packages the standing rule is:
**every target maps to exactly one top-level source folder, and the folder is
the target's home** (`Sources/<TargetName>/`, `Tests/<TargetName>Tests/`). No
`path:` pointing many targets into a shared parent, no disjoint `sources:` /
`exclude:` slicing to carve multiple targets out of one folder. `ls Sources/`
must enumerate every target; the filesystem boundary IS the target boundary.

This supersedes the older "family-parent folder" guidance below for the
target-grouping case. The file-grouping rules (grouping FILES *within* a single
target's folder) still apply unchanged. The two earned-exception patterns
(same-kind single-file clusters; sub-targets sharing an umbrella) are now
discouraged for new code; flatten unless there is a compelling, documented reason.

A migration that flattened a deep `Sources/{Core,Executables,Retailers}/...`
tree to strict one-folder-per-target confirmed the payoff: a cluster of
executables sliced from one folder via `sources:` became sibling
`Sources/<X>/` folders, with a byte-identical behaviour set and a fully green
test suite across the migration.

## The rule (grouping FILES within a target)

1. **Group related files in a shared parent folder.** When you have several files that belong to the same semantic kind (e.g. 27 importers, 5 renderers, 12 view-models), put them under a single parent folder named for the kind (`Importers/`, `Renderers/`, `ViewModels/`). Do not scatter them across the root or across one-folder-per-file silos.

2. **Don't create a subfolder for a single file.** A subfolder's job is to make a group of related files easy to scan. A subfolder containing exactly one file forces an extra click / expand without giving anything back; that one file should live one level up.

3. **Exception: a single-file folder is allowed when the file's semantic differs sharply from its siblings.** Use this when the file *anchors a future group* or when collapsing it up would put it next to unrelated things. Example: the first file dropped into a brand-new utility / domain bucket may keep its own folder so the bucket's purpose is visible even before peers arrive. Apply sparingly. The default is to flatten.

4. **The rule applies recursively at every nesting level.** Each level of nesting must have a semantic justification. After grouping a kind into a parent folder (`Importers/`), look INSIDE that parent: are there sub-clusters that share a finer semantic? Pull those into their own subfolders. After that pass, look UP one level: is the parent kind folder a peer of other related kind folders (`Importer/` seam + `ImporterUtilities/` + `Importers/` are all import-related)? Wrap them in a common ancestor (`Import/`). Walk the tree once top-down, once bottom-up. Every folder boundary at every depth must answer "what semantic distinguishes the things inside from the things outside?" If it cannot, flatten or rename.

## Naming the parent folder: singular vs plural

The kind folder's name is **singular**, not plural. A folder grouping many models is `Model/`, not `Models/`. A folder grouping many passes is `Pass/`, not `Passes/`. The folder name describes the *kind of thing inside*, not the *plural cardinality of that thing*. Singular reads cleaner in paths (`Sources/Enrichment/Model/EnrichmentRunner.swift` vs the noisier `Sources/Enrichment/Models/EnrichmentRunner.swift`) and matches the Swift namespace style (`Indexer.Model.X` not `Indexer.Models.X`).

Exception: the kind-folder name is plural *only when the kind itself is grammatically a plural noun* (`Resources/`, `Frameworks/`, `Sources/` itself). When you have to coin a singular vs plural, pick singular.

## SPM default: every target is its own top-level folder

The Swift Package Manager default, `Sources/<TargetName>/<files>` with no `path:` override, is the safer baseline for packages with many SPM targets. The filesystem location mirrors the target identity one-to-one, which means:

- `ls Sources/` enumerates every target without reading `Package.swift`.
- `grep -r ... Sources/Foo/` answers "what's in target Foo" without ambiguity.
- Lift-out is trivial: copy the folder, write a 5-line standalone `Package.swift`, build.
- New contributors do not have to learn an additional layer of conventions before navigating the tree.

Deviate from SPM default ONLY when one of the two patterns below earns its keep.

## When family-parent folders are worth it: same-kind clusters of single-file targets

A family parent folder with `path:` + `sources:` overrides earns its keep when you have **5 or more peer targets of the same semantic kind**, each a single-file standalone target. The worked example below is the canonical case: 27 importers under `Sources/Importers/<name>.swift`. The kind folder collapses 27 single-file siblings into one scannable list, and SPM's `path:` + `sources:` keeps each importer a separate target.

The rule of thumb: if you can name the kind in one word and you have many peers, group them. `Importers/`, `Renderers/`, `ViewModels/` qualify. Two targets do not.

## When family-parent folders are *not* worth it: heterogeneous-kind families

A family folder with **kind-named subfolders** (`Sources/<Family>/{Core, Model, ...}/`, where each subfolder holds a different kind of target: live concrete vs foundation seam vs WebKit adapter) is an anti-pattern. It looks symmetric but:

- The filesystem path no longer maps 1:1 to a target. `Sources/Enrichment/Core/` is the target `Enrichment`; `Sources/Enrichment/Model/` is the target `EnrichmentModels`. The reader needs `Package.swift` to make the connection.
- Overloads the word "Core" across multiple meanings (family root, target's content, kind subfolder).
- Reads worse: `Sources/Source/SampleCode/SampleCodeSource.swift` triples the same word.
- Forces every new contributor to learn a project-specific taxonomy before navigating.

If a `Foo` target ships alongside `FooModels`, leave them as `Sources/Foo/` + `Sources/FooModels/` (SPM default). The naming pair already signals the relationship; folder nesting adds nothing.

**Historical note**: one project tried `Sources/<Family>/{Core, Model, ...}/` across 13 families before reverting to SPM default after a single review pass: "this is confusing." The lesson: filesystem === target boundary is load-bearing for navigability; family-parent folders that obscure it are not worth the cohesion gain.

## Target name vs folder name decoupling

SPM target identity is declared via `path:` in `Package.swift`. The filesystem location and the target name can diverge, but **do not make them diverge for cosmetic reasons**. Use `path:` only when:

1. **Clustering same-kind single-file targets** (the Importers case).
2. **Embedding a sub-target inside a parent target's folder** (e.g. `Sources/MCP/Core/`, `Sources/MCP/Client/`: each is its own SPM target but they share the umbrella name because they ship together as one conceptual framework).
3. **Test targets pre-organised under a domain folder** (`Tests/MCP/CoreTests/`, `Tests/CLICommandTests/DoctorTests/`) when the source side mirrors that shape.

Anywhere else: keep SPM default. The discoverability win outweighs any cohesion gain.

## Rename priority order (highest-stability first)

When restructuring or renaming, treat the surfaces in this order. The higher the stability rank, the more reluctant you must be to change it. **Always anchor a rename around the highest-stability surface that is not moving**, and let the lower-rank surfaces follow.

1. **SPM target name**, *highest stability*. This is the string consumers write as `import <TargetName>`. Changing it cascades to every consumer's source file, every test file, every doc that names the import, every script that greps for it. Default position: do not rename. A target rename is a separate, dedicated PR with explicit acceptance criteria (every consumer updated, every test green, every doc swept).

2. **Public type / namespace name**, *high stability*. Surfaces in consumer code as `<TargetName>.<TypeName>`. Renames are tractable because they can be staged behind a `public typealias OldName = NewName` for back-compat, but every direct reference still needs updating eventually. Stage the rename: introduce the new name + alias in one PR, migrate consumers in follow-ups, drop the alias when uses hit zero.

3. **File name**, *low stability*. The Swift compiler does not care what file a type lives in. Rename freely. Common patterns: `<Namespace>.<Type>.swift` for namespace-anchored types. `git mv` and you are done; no consumer is affected.

4. **Folder layout**, *lowest stability*. The filesystem location of source files is an organisational decision, not an identity one. SPM `path:` overrides decouple folder from target name when needed (sparingly, see the section above). Reorganise folders without touching target names: every consumer keeps building unchanged.

**The load-bearing principle**: when renaming, ask first *"can I do this without touching the SPM target name?"* If yes, the change is local. Only the codebase author sees the file moves. If no, the change is API-breaking and needs the heavy-PR treatment.

**Worked example**: a family-folder restructure attempted to deepen a codebase by moving source files into family-parent + kind-subfolder shapes. The instinct was right (organize better) but the execution prioritised the wrong surface (folder layout over target name). After a single review pass on the result ("this is confusing") the right move was to keep target names + file names exactly as they were and revert the folder layout to SPM default. The same PR also landed type-name deepening (rank 2 above) with back-compat typealiases, which DID stick because it respected the priority order: target names unchanged, public types staged behind aliases, file names + folders adjusted to match. The folder restructure (rank 4) cost roughly 250 file moves in then out; the type deepening (rank 2) cost about 6 files and shipped. Different ranks, different blast radii.

## How to apply

When adding a new file:

- Find an existing folder of the same kind. Drop the new file directly into it (no inner subfolder).
- If the file has multiple companion files of its own (a 2-or-more-file unit: protocol + helper + fixture, or model + parser), give *that unit* its own subfolder inside the parent kind folder.
- If no kind folder exists yet and the new file is the first of its kind, drop it next to its peers at the current level. Create the kind folder later, when a 2nd peer lands.

When reviewing an existing tree:

- Walk it folder-by-folder. Any folder containing exactly one `.swift` / `.py` / `.md` / etc. file is a candidate to flatten.
- Flatten by `git mv`-ing the file up one level and `rmdir`-ing the now-empty folder.
- Preserve the unit-with-multiple-files rule: do not flatten a 2-file folder.

## How this composes with SPM (Swift specifics)

This rule conflicts with SPM's default `Sources/<TargetName>/<files>` convention when you have many single-file targets, because SPM expects one folder per target. Resolve by giving each affected target an explicit `path:` and `sources:` declaration in `Package.swift`. Multiple targets MAY share the same `path:` as long as each declares disjoint `sources:` lists. Example:

```swift
let importersSrc = "Sources/Importers"

func flatImporter(_ name: String, dependencies: [Target.Dependency]) -> Target {
    .target(
        name: name,
        dependencies: dependencies,
        path: importersSrc,
        sources: ["\(name).swift"]
    )
}
```

Then `flatImporter("AnalysesImporter", ...)`, `flatImporter("FollowersImporter", ...)`, etc. all live as flat `.swift` files under `Sources/Importers/` while remaining independent SPM targets. A multi-file target (e.g. one with a protocol + a CSV parser) keeps its own subfolder under the parent kind folder: `path: "Sources/Importers/CsvImporter"`.

Verified on Swift 6.0 + SPM: `path:` may overlap between targets when `sources:` partitions them disjointly.

## Tests follow sources

Test files mirror their source layout:

- 26 single-file importers under `Sources/Importers/` map to 26 test files under `Tests/Importers/`.
- A multi-file importer at `Sources/Importers/CsvImporter/` maps to a multi-file test target at `Tests/Importers/CsvImporterTests/`.

Use the same `flatImporterTests(...)` helper pattern in `Package.swift`.

## Why this matters

Two costs the rule removes:

- **Scan cost.** A tree with 27 one-file folders is 27 expand-arrows the reader has to click. A flat `Importers/` directory with 27 files visible at once is one find-in-files away from any target. Brevity wins.
- **Mental overhead during edits.** When all importers are siblings, "show me what every importer does" is `ls Sources/Importers`. When each importer hides one level down, the same question becomes `find Sources/*Importer -name '*.swift'` plus a mental merge.

The cost the rule preserves: SPM-level target independence (every package lifts out of the package set cleanly). Folder-grouping is a *filesystem* layout decision; SPM-target boundaries stay sharp via `path:` + `sources:`.

## Lift-out preservation (non-negotiable)

Every package must lift out as a working standalone Swift package: copy the target + its declared transitive deps to a tmp directory, generate a minimal `Package.swift`, `swift build`, green. Folder-grouping must not regress this.

It does not, because:

- Each target still owns a definite set of `.swift` files (declared via `path:` + `sources:` in `Package.swift`). The filesystem locations are colocated, but the file-to-target mapping is unambiguous.
- A lifted target re-roots its sources under the default SPM convention (`Sources/<TargetName>/<files>`); the shared-path trick was a *package-set* layout choice, not part of the target's identity. The lifted-package `Package.swift` goes back to plain `.target(name: "X", dependencies: [...])` with no `path:` override.
- Tests follow the same rule: each test target's `.swift` files belong to exactly one test target, and lifting copies just those files.

**Mechanical verification (do this when in doubt):** copy the importer + its declared transitive deps to a tmp `Sources/<Name>/<files>` (one folder per target, default layout), generate a one-screen `Package.swift`, `swift build`. Green = lift-out works.

**Per-target import audit must still work.** A side-effect of shared `path:` is that simple `for d in Sources/*; do audit "$d"; done` scripts collapse a cluster of single-file targets into one bucket and lose per-target granularity. Fix: walk to leaf `.swift` files inside designated cluster directories. Add an `is_cluster_path` predicate to the audit so each clustered target is still audited individually; update that predicate when adding a new cluster bucket.

If the audit script cannot distinguish your targets, the refactor is leaking: fix the script or revert the grouping. The lift-out test never lies.

## Worked example: a three-pass flatten

Three passes, each from a different angle, illustrating rule item 4.

**Pass 1, flatten one-file folders.** Before: `Sources/AnalysesImporter/AnalysesImporter.swift`, `Sources/FollowersImporter/FollowersImporter.swift`, ... 27 one-file folders at the `Sources/` level. After: `Sources/Importers/<name>.swift` flat. The 2-file `CsvImporter` keeps its inner subfolder.

**Pass 2, sub-cluster inside the kind folder.** The flat list `Importers/` still had visible clusters: several files sharing a platform prefix. Each cluster got its own subfolder under `Importers/`. Single-file importers with no platform peer stayed flat at `Importers/`.

**Pass 3, wrap the import family at the root.** `Sources/` contained `Importer/` (seam), `ImporterUtilities/` (helpers), and `Importers/` (concretes) as three peer folders mixed with unrelated things. The three import-related folders got wrapped under `Sources/Import/`. Final import-side layout:

```
Sources/Import/
|-- Importer/                    (seam, multi-file)
|-- ImporterUtilities/           (helpers, multi-file)
+-- Importers/                   (concretes)
    |-- PlatformA/               (multiple PlatformA targets)
    |-- PlatformB/               (multiple PlatformB targets)
    |-- AnalysesImporter.swift   (flat, no platform peer)
    +-- SnapshotImporter.swift
```

Tests mirror the same shape under `Tests/Import/`. Build + tests + the live CLI pipeline all pass.

The lesson: pass 1 and pass 2 are both applications of the same rule at different depths. Pass 3 inverts the angle, looking UP from a kind folder at its peers, and finds the next grouping. After three passes the tree settles: every folder at every depth has an answer to "what's inside that is not outside?"

## Anti-patterns

- Creating an `Importers/AnalysesImporter/AnalysesImporter.swift` triple where the inner folder holds one file. Flatten.
- Hoisting a multi-file unit (e.g. an importer's protocol + CSV parser) out of its subfolder and into the flat parent. The unit deserves its own folder.
- Inventing a single-file kind folder before peers exist (a brand-new `Renderers/WebDashboardRenderer.swift` when no other renderer is anywhere on the horizon). Wait for a 2nd renderer, then create `Renderers/` and consolidate.
- Creating a parent kind folder that contains only one item *and* duplicates its name (e.g. `Renderers/Renderers/Web.swift`). Same anti-pattern as `Renderers/Web/Web.swift`: the inner layer is empty.

## Enforcement

No automated linter today. Verify by eyeballing the tree before declaring a layout change done:

```bash
find Packages/Sources -mindepth 1 -maxdepth 1 -type d | while read d; do
  count=$(find "$d" -maxdepth 1 -name "*.swift" | wc -l | tr -d ' ')
  printf "%3s  %s\n" "$count" "$d"
done | sort -n
```

Any line with `1` is a candidate for flattening (unless rule item 3 applies).

## See also

- docs/rules/file-naming.md: filename conventions this layout sits on top of.
