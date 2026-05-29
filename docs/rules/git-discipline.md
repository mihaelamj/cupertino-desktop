# GitHub and Git Discipline

Conventions for issues, labels, pull requests, branches, commits, and remotes in the Tiledown repo. Commit-message format lives in docs/rules/commits.md; this file covers everything else.

The repo ships issue forms, a PR template, a label set, and git hooks that enforce most of these rules mechanically. The rules below are the durable conventions those mechanisms encode.

## 1. Issue tracker

### Rule 1.1: Status block at the top, dated

Every issue body carries a `## Status (YYYY-MM-DD)` heading as the first section. New-issue form templates make this required.

When state changes (work starts, acceptance bullets ship, scope narrows, deps close), edit the status block in place with a new date line. The rest of the body stays as the original framing.

**Why**: bodies without a dated status block age into fiction within a month. Issues with status blocks age well; the ones without age into wrong-default-value claims that shallow audits pass as "well-written, keep."

### Rule 1.2: No line numbers in issue bodies

File references use symbol names, not `Foo.swift:142`. Lines drift on every PR; symbols do not.

When you need a line anchor, write `Foo.swift (the searchSymbols function)` so the symbol survives even if the line moves.

**Why**: line anchors like `SearchIndex.swift:2409` go dead within one PR cycle the moment a file is split or reordered.

### Rule 1.3: No phantom paths

Every backtick-quoted file path in an issue body must EXIST in the repo (or in a declared sibling repo) at write time.

A mechanical check on this is straightforward: extract backtick-quoted paths, check the filesystem, flag missing ones.

**Why**: a cited file that was never written is a fabrication that propagates. The work it implies may be real, but the path is a lie until the file exists. File it as an issue instead of citing a path that is not there.

### Rule 1.4: Cross-reference hygiene

When citing `#NNN` in blocker phrasing ("blocked on", "pending in", "depends on", "after #N lands", "gated on", "awaits", "waiting on"), the referenced issue must be OPEN at write time.

When the referenced issue closes, edit the citing issue's body: either remove the cross-reference, or rewrite the surrounding sentence to say the dep shipped.

**Why**: "blocked on #X" where #X closed weeks earlier is a silent dependency lie. Wrong issue numbers are worse: they point a reader at unrelated work.

### Rule 1.5: Schema and code claims are checkable

Do not cite `<table>.<column>` shapes, function signatures, or default values you have not verified against current source.

When the claim is structural (a schema column, a config default, a flag name), an audit script can mechanically verify it. Migrations move columns; flag defaults change; bodies do not auto-update.

**Why**: a body claiming a column lives in table A when a migration moved it to table B, or claiming a flag defaults to `0.5s` when the real default is `0.05s` (off by 10x), reads as authoritative and misleads. Verify before you write.

### Rule 1.6: Issue templates use GitHub forms, not markdown

Use `.yml` form templates, not `.github/ISSUE_TEMPLATE/feature.md` style markdown. Forms enforce structure mechanically at filing time; markdown templates only suggest it.

Required fields: status date (input), priority (dropdown), complexity (dropdown). Required structured textareas per template kind (goal + acceptance for features; symptom + expected + reproduce + acceptance for bugs).

**GitHub forms gotcha**: dropdown selections produce TEXT in the issue body under `### <field label>` headings; they DO NOT auto-apply as labels. To make dropdowns actually apply matching labels, add a labeler workflow that triggers on `issues.opened`, extracts the value under each heading, validates against the known label set, and applies the matching label.

**Why**: forms make filing discipline structural rather than suggestive. The labeler gotcha is easy to miss; the dropdowns look like they should label the issue, and they do not.

## 2. Labels

### Rule 2.1: Brutal-minimum 5-label set

The canonical label set is **5 labels**. Labels exist only to mechanically partition the issue space; everything else lives in the issue body or in native GitHub primitives (issue state, Milestones, Project boards).

| Label | Color | Use |
|---|---|---|
| `bug` | Red `#FF3B30` | Something ships incorrectly |
| `enhancement` | Blue `#007AFF` | New feature, refactor, or design proposal |
| `epic` | Purple `#AF52DE` | Aggregation parent of related issues; mechanically excluded from "missing kind" check |
| `priority: high` | Red `#FF3B30` | Critical / release-gating / actively-blocking. Absence means "do when you can." |
| `good first issue` | Green `#34C759` | Newcomer-friendly; GitHub renders specially in the contributor chooser |

Kind is determined at filing time (feature template applies `enhancement`, bug template applies `bug`). Maintainers add `epic`, `priority: high`, `good first issue` post-filing where warranted.

**What is not a label here:**

- **Complexity.** Read the diff. If you need a label to tell readers the issue is hard, your prose is failing.
- **Priority gradient.** `priority: medium` and `priority: low` collapse to "absence of `priority: high`." If the gradient does not change behaviour, the gradient is decoration.
- **Topical categorisation** (search-quality, source-expansion, refactor, area: distribution, etc.). These are composition, not type. Encode in the body or in a milestone.
- **Status / lifecycle** (`wishlist`, `transitional`, `blocker`, `big-win`, `fixed: awaiting release`, `released-in: v<X.Y.Z>`). Status belongs to GitHub-native primitives (issue state, Milestones, Project boards), not to labels.

**Why this size**: each surviving label has at least one mechanical reason it cannot fold into the body. Form templates apply kind at filing time; a staleness script partitions on `epic`; `priority: high` is the only triage tier (absence is implicit "later"); `good first issue` is GitHub-native. Three lenses converge on this set:

- **Cut mercilessly**: cut even fine things that do not earn their place. A larger set still carries comfort-tags.
- **Classify by type, not status**: every classification must justify its existence; status / lifecycle / release-tracking are not types, route them to native primitives.
- **Prose over labels**: if you need a label to convey something, your prose is failing. Labels exist only for what mechanical tools must partition on.

### Rule 2.2: 3-carrier threshold for adding a new label

If you feel the urge to add a sixth label, ask: does this label have at least 3 expected open carriers (today or within the next planning cycle)? AND does it survive each of the three lenses above?

- Would you ship this label, or delete it?
- Is this a type/axis, or is it status/lifecycle/composition pretending to be a type?
- Does this label mechanically partition the issue space in a way grep / filter / a CI script must use, or is it commentary that belongs in the body?

If any lens fails, fold the categorisation into the issue body. A one-line note in the body is as discoverable as a single-carrier label without the dropdown clutter.

**Why**: single-carrier labels are footnotes pretending to be axes. Sprawling label sets stop being navigable past about 10.

### Rule 2.3: Apple system palette

The 5 canonical labels use 4 hues from Apple's published system colour palette:

| Hex | Color | Use |
|---|---|---|
| `#FF3B30` | Red | Urgent / blocking: `bug`, `priority: high` |
| `#007AFF` | Blue | Active work: `enhancement` |
| `#AF52DE` | Purple | Aggregation / epic: `epic` |
| `#34C759` | Green | Newcomer-friendly / shipped: `good first issue` |

If you add a sixth label under Rule 2.2, draw from Apple's other system colours by semantic grouping:

| Hex | Color | Reserved for |
|---|---|---|
| `#FF9500` | Orange | Medium urgency |
| `#FFCC00` | Yellow | Awaiting / pending |
| `#00C7BE` | Mint | Low complexity (if you ever bring complexity back) |
| `#30B0C7` | Teal | Topical / categorical |
| `#32ADE6` | Cyan | Help / outreach |
| `#5856D6` | Indigo | High complexity / structural |
| `#FF2D55` | Pink | Celebration / high-impact |
| `#A2845E` | Brown | Maintainer / internal |
| `#8E8E93` | Gray | Speculative / wishlist |

**Why Apple's palette**: 13 distinct hues with strong semantic associations. Picking from this set means labels render coherently in any view that supports colour (GitHub UI, project boards, third-party trackers reading from GitHub).

### Rule 2.4: Label deletion is destructive on closed issues

`gh label delete <name>` removes the label from every issue that ever bore it, including closed issues. Use `gh label edit --name <new>` to rename when historical association matters.

**Why**: closed issues are the project's audit trail. A `phase-1` label on closed refactor issues told a later reader "this was Phase 1 of that refactor"; deleting `phase-1` removes that context. Renaming preserves it.

When in doubt: prefer rename over delete for labels with closed carriers. Brutal trims that delete closed-carrier labels should be a deliberate, documented choice (acceptable when the information still lives in Release notes, the CHANGELOG, and merge commits).

## 3. Pull requests

### Rule 3.1: One focused change per PR

A PR ships one cohesive change. If the diff spans two unrelated concerns, split.

Critic-fix iterations on the same change belong in the same PR (separate commits, same branch). Different concerns belong in different PRs even if they touch the same files.

### Rule 3.2: CHANGELOG required for non-trivial changes

Projects that maintain a CHANGELOG require an entry per non-trivial PR. "Non-trivial" means: production source touched. Trivial means: docs / tests / scripts / configuration only.

A mechanical pre-commit + CI check enforces this. Opt-out via a `[no-changelog]` token in the commit message body when the change genuinely does not warrant an entry.

**Why**: PR descriptions live in the merge graph; CHANGELOG lives in the release. Without enforcement, source ships ahead of its description. A mechanical gate prevents the batch of PRs that merge without entries.

### Rule 3.3: Critic-fix loop on every non-trivial PR

After opening a PR, do a self-critic pass: read your own diff as a reviewer would, find issues, fix them in additional commits on the same branch. Iterate until critique surfaces nothing new.

Commit naming: `critic-fix(<scope>): <what was wrong>`. The git history shows the iteration as separate commits; the PR diff shows the converged result.

**Why**: mechanical edits without re-reading the surrounding paragraph create new bugs. A `sed` that injects a reference inside a sentence saying "this is independent" creates a contradiction. Critic-fix loops catch the self-introduced bugs that the original change did not have.

### Rule 3.4: PR head is never the canonical branch for release merges

When merging a release branch into `main` (or `develop` into `main`, etc.), the PR head is a dedicated `release/v<X.Y.Z>` branch, not the canonical working branch. Auto-delete-on-merge would kill the canonical branch otherwise.

**Why**: the GitHub auto-delete-branch-on-merge feature is useful for short-lived feature branches and destructive for long-lived development branches. Always interpose a release branch as the head.

## 4. Branches

### Rule 4.1: Branch naming

- `fix/<issue>-<topic>`; bug fixes (e.g. `fix/284-error-page-filter`)
- `feat/<topic>`; features
- `chore/<topic>`; tooling, infrastructure, non-functional cleanup
- `docs/<topic>`; documentation-only changes
- `refactor/<topic>`; structural code reorganisation
- `release/v<X.Y.Z>`; release-prep branches (PR head for canonical-branch merges per Rule 3.4)

Issue-anchored prefixes (`fix/<NNN>-...`) when an issue exists; otherwise topic-anchored.

### Rule 4.2: Branch from canonical base

Branch from the current tip of the canonical base branch (the one the PR will target). For Swift projects this is usually `main` or `develop` depending on the project's branching model.

`git fetch origin <base> && git checkout -b <new-branch> origin/<base>` is the safe form. Branching from a stale local copy of the base creates merge conflicts later.

### Rule 4.3: Issue-first workflow

For every bug fix: file the GitHub issue first, then branch. The branch name carries the issue number; the PR auto-links via `Closes #N` in the description.

For features: an issue is optional but recommended when scope is non-trivial or when the change crosses two or more bug-list cycles.

**Why**: the issue is the audit trail. A branch + PR without an issue has no place for the symptom / repro / acceptance discussion. The PR body can hold that data but does not survive squash-merge as well as an issue does.

## 5. Commits

See docs/rules/commits.md for commit message format. The following are additional GitHub-related conventions.

### Rule 5.1: No AI attribution

Generated content carries no AI attribution in any committed text. Specifically forbidden:

- Any AI co-author line in commit messages
- Tool-attribution lines in PR descriptions, code comments, or documentation
- The names of AI tools or vendors, or the words "AI", "LLM", "agent", "assistant", "automated", "machine-generated", or any synonym, in commits / PRs / branch names / file names that could end up in front of a colleague
- AI-tell stylistic patterns: emoji signatures, "Here's a quick summary:" preludes, gratuitous emoji-prefixed bullets, "I'll now..." / "Let me..." preambles in committed text
- Watermarks: zero-width characters, hidden HTML comments naming a tool, branch suffixes like `-ai` / `-bot`

The work must read as entirely human-authored. The standard is "would a colleague reading this guess a tool wrote it?" If yes, remove it.

For mechanical enforcement at the commit boundary, install the commit-message style hook described in Section 7. Rule 5.1 plus Rule 5.2 plus the hook together close the loop: the rule states intent, the hook refuses violations at commit time, so no commit reaches `git push` carrying either failure.

### Rule 5.2: No em dashes in committed text

The em dash (the U+2014 character) is a recognisable writing tell. Replace with commas, periods, colons, semicolons, or restructure the sentence. Apply to commit messages, PR descriptions, code comments, issue bodies, documentation, README content; everything that lands in the repo or in front of a colleague.

This is a stylistic rule, not a syntactic one. En dashes (U+2013) and hyphens (U+002D) are fine. Only the em dash is forbidden.

Enforced mechanically by the commit-message style hook in Section 7 for commit messages. For file content, run the same byte check in a `pre-commit` hook over staged diffs.

### Rule 5.3: Verify after `git commit --amend --no-edit`

`--no-edit` keeps the previous commit's message verbatim. After any amend with `--no-edit`, run `git log -1` to confirm the message still describes the new tree accurately. If the staged change made the previous message wrong, drop `--no-edit` and rewrite.

**Why**: silent message staleness is the second-easiest commit-history bug to introduce (after force-pushing the wrong branch). The previous message gets anchored by `--no-edit` and lies about content that has since changed.

## 6. Remotes

### Rule 6.1: Push conventions

Pushes follow the usual conventions: short-lived feature branches push freely; canonical branches (`main` / `develop`) only land via merge of an approved PR.

## 7. Mechanical enforcement

A repo that adopts these rules should ship a mechanical backstop:

- **Body-drift scan**: a scheduled script that greps open issue bodies for renamed paths, phantom paths, stale cross-refs, stale schema claims, and label drift. Output goes into a single tracking issue that gets updated on each run.
- **CHANGELOG gate**: a pre-commit hook + CI gate that refuses commits / PRs touching production source without a CHANGELOG entry.
- **Issue forms with labeler**: GitHub form templates for new issues + a workflow on `issues.opened` that translates form dropdown values into matching labels.
- **Style-tell commit-msg hook**: a `commit-msg` hook that refuses messages containing em dashes (U+2014), the forbidden AI-attribution phrases from Rule 5.1, or AI-signature emojis. Keep it portable (BSD-grep compatible, no PCRE dependency). Install per repo by symlink or copy into `.git/hooks/commit-msg`. Strip comment lines and the diff scissors block before checking so notes in `# ...` lines are not penalised.

**Why mechanical enforcement matters.** A disciplined author following Rule 5.2 can still push a commit whose message contains an em dash, because nothing at the commit boundary stops it. A 3-line `commit-msg` hook prevents this entire failure class at write time, after which `git push` cannot carry a violation regardless of who or what wrote the message. Discipline scales with attention; hooks do not.

## Triggers (when to load this rule)

Load this rule when:

- Filing a new GitHub issue (Rule 1.1, Rule 1.2, Rule 1.3, Rule 1.6)
- Editing an open issue body (Rule 1.1, Rule 1.4, Rule 1.5)
- Adding or deleting a GitHub label (Rule 2.1, Rule 2.2, Rule 2.3, Rule 2.4)
- Opening a PR (Rule 3.1, Rule 3.2, Rule 3.3, Rule 3.4)
- Creating a branch (Rule 4.1, Rule 4.2, Rule 4.3)
- Writing a commit message that will be pushed (Rule 5.1, Rule 5.2)
- Running `git commit --amend` (Rule 5.3)
- Running `git push` (Rule 6.1, Rule 6.2)
- Designing a tracker-discipline mechanism for a new repo (Rule 7)

Load on demand per the trigger; do not auto-load.
