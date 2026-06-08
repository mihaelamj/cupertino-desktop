# Decision: navigate large documentation hierarchies by Degree-of-Interest, not flat lazy-loading

**Status:** Proposed (design direction for #49/#50; nothing built yet).
**Date:** 2026-06-08.
**Related:** [ui-abstraction-seam.md](ui-abstraction-seam.md) (this is a concrete
instance of "grow the Logical Presentation as data"); issues #49, #50, #51.

## Context

A framework documentation tree can be enormous: the sidebar already shows counts like
Kernel 39,651 and SwiftUI 8,679 documents. #50 wants the whole framework tree
(framework to API collections to symbols to members) navigable the way Xcode's
documentation navigator is.

**Current code state (audited 2026-06-08):**

- `Model.Framework` is flat: `{ id, name, documentCount }`, no children.
- Selecting a framework loads exactly one overview document
  (`Feature.FrameworkBrowser.ViewModel.loadDocument(framework:)`: a framework-scoped
  search, `limit: 1`, read the first hit). There is no tree.
- `Feature.Search.ResultNode` is a recursive `Hashable, Identifiable` tree, but it is
  inert (no shell renders it) and `resultTree(docs:)` groups only one level.
- No lazy-loading, degree-of-interest, fisheye, or focus+context logic exists anywhere.

So #50 is greenfield. `ResultNode` is the closest existing shape to reuse.

## The naive approach and why it is not enough

"Lazy-expand an `NSOutlineView` / `OutlineGroup`, load children on demand" keeps the
whole tree from materializing, but it does not solve navigation: a user three levels
deep in a 39k-node tree still has no sense of where they are, and reaching a sibling
far away is many expand/collapse steps. The HCI literature settled this in 1986.

## Decision (direction)

Model the tree as data with a **Degree-of-Interest (DOI)** function and render only
the interesting frontier, recomputed cheaply as the focus moves. Furnas (CHI '86)
defines, for a focus node `y`:

```
DOI(x | focus = y) = API(x) − D(x, y)        // interest = importance − distance
```

with the exact tree instantiation:

```
API(x)        = − d_tree(x, root)            // closer to the root = more important
D(x, y)       =   d_tree(x, y)               // path-length distance to the focus
DOI(x | y)    = − ( d_tree(x, y) + d_tree(x, root) )
```

Display by a threshold `k`, showing only nodes with `DOI ≥ k`: `k = −3` is the
ancestral lineage from focus to root, `−5` adds that lineage's siblings, `−7` adds
cousins. Three properties from the paper make this fit a Kernel-sized tree:

1. The view is logarithmically compressed: its size scales with the log of tree size.
2. View cost is proportional to the size of the *view*, not the *tree*, so 39k nodes
   never materialize (this subsumes lazy-loading).
3. On a focus change from `y` to `y'`, "the change in view is easily calculated, since
   the whole DOI function above their common ancestor is unchanged": cheap incremental
   recompute on every navigation step.

Furnas's own navigation study found users 75% correct with two fisheye views versus
52% with two flat views.

## How it lands in this codebase

- Give the framework tree a node model shaped like `ResultNode` but carrying depth and
  a computed `doi` relative to the current focus (the node model is shared, framework-
  agnostic data: the "grow the Logical Presentation as data" rule from the seam
  decision). Keep it data, not a widget.
- Reify it natively per shell (the seam decision): `NSOutlineView` (AppKit),
  `UICollectionView` outline / section snapshot (UIKit), `OutlineGroup` (SwiftUI). The
  DOI thresholding and elision live in the shared model; each shell only draws the
  resulting frontier. `ResultNode`'s `Hashable` identity already suits diffable section
  snapshots for the AppKit/UIKit outlines.
- The backend still supplies children on demand (the `list_children` primitive tracked
  upstream for #50); DOI decides which expanded nodes stay visible, the backend decides
  what a node's children are. The two compose.

## When to revisit

If usage shows the trees are small enough in practice that plain lazy expansion
suffices, the DOI layer is unnecessary complexity. Decide against a real corpus, not in
the abstract. Until #49/#50 are built, this is a direction, not a commitment.

## References

- Furnas, Generalized Fisheye Views, CHI '86 (primary): <https://dl.acm.org/doi/10.1145/22627.22342>
- Card, Nation, Degree-of-Interest Trees, AVI 2002: <https://dl.acm.org/doi/10.1145/1556262.1556300>
- Plaisant, Grosjean, Bederson, SpaceTree, IEEE InfoVis 2002 (IEEE VIS Test-of-Time
  Award 2022): <https://ieeexplore.ieee.org/document/1173148/>
