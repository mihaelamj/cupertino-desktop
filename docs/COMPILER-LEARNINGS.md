# Compiler Construction Learnings

Study notes taken while auditing this engine against the standard literature. Two books, both in
this folder: the Dragon Book (Aho, Lam, Sethi, Ullman, *Compilers: Principles, Techniques, and
Tools*, 2nd ed., `Dragon-book.pdf`, PDF page = book page + 23) and Cooper and Torczon,
*Engineering a Compiler*, 2nd ed. (`Engineering A Compiler ... .pdf`, PDF page = book page + 25).
These are learnings, not summaries: each entry records what the book taught, what it changed (or
confirmed) in this engine, and where the proof lives. The engine is the XCTemplateDSL compiler
family; every claim marked *corpus-proven* was verified over all 10,117 templates via
`swift scripts/check-corpus.swift all` (gates: roundtrip, check, ast, expand).

## Part 1: Dragon Book (audited to convergence, 2026-06)

### 1. A compiler is phases, and the phase boundaries are API boundaries (§1.2)

Lexical analysis, syntax analysis, semantic analysis, intermediate representation, synthesis. The
deep lesson is not the list but the discipline: each phase has one input, one output, and one
failure vocabulary. That shaped the engine's public surface: `tokenizeRecovering()` returns
`(tokens, lexicalErrors)`, `parseRecovering()` returns `(bundle?, syntaxErrors)`, the validator
returns semantic findings, and the `check` command is the composition of all three with the
avalanche rule (semantic findings are suppressed while syntax errors exist, because a broken tree
only produces spurious findings). It also shaped the TemplatoIDE engine seam: analysis operations
never throw, synthesis operations do.

### 2. Panic-mode lexical recovery is single-edit repair (§3.1.4)

A lexer should not stop at the first bad character. The panic-mode discipline: record the error,
delete one character, continue. With it, one pass over a broken file yields every lexical error
with positions. The subtlety learned by doing: an unterminated string should still yield its
partial lexeme as a token, so the parser downstream sees something plausible and the user gets one
error, not a cascade.

### 3. FIRST and FOLLOW are computed, not intuited (§4.4.2)

The three-rule fixed-point computation for FIRST and the FOLLOW iteration are mechanical. Writing
them down for the DSL grammar (now in `GRAMMAR.md`) exposed that the parser's hand-written
lookahead decisions had been correct but unjustified. The tables are the justification, and the
recovery sets are *derived* from them, not hand-picked. Rule learned: if a parser decision cannot
be pointed at a row of the FIRST/FOLLOW table, it is folklore, not engineering.

### 4. LL(1) is a property you prove once and then protect (§4.4.3)

The grammar is LL(1) because every construct is introduced by a distinguishing token and the
epsilon productions' FOLLOW sets are disjoint from the alternatives' FIRST sets. The proof lives in
`GRAMMAR.md`; any grammar change must re-run that argument. Keywords are deliberately NOT reserved
(`option`, `unit`, `node`, `directory`, `template` reach the parser as IDENT and disambiguate by
value), which keeps them usable as plist keys; the LL(1) argument still holds because the value
test happens exactly at positions where the grammar expects a keyword.

### 5. Panic-mode parser recovery: resume sets AND the pop action (§4.4.5, Fig 4.22)

Recovery is not just "skip to something in FIRST(item)". The figure's `synch` entries encode a
second action: when the offending token can only start an *enclosing* construct, the right move is
to close the current construct WITHOUT consuming the token (the stack shortens, the token is
re-examined one level up). Implementing only the resume half mis-attaches constructs: a `node`
stranded inside an `option` body must pop out to template level, not be swallowed. The ordering bug
found while implementing this: the pop test must happen at the error position BEFORE the
progress-guard consumes a token, or recovery skips INTO the stray construct's body.

### 6. Success means the WHOLE input (§4.4.1)

A parse that consumes a valid prefix and ignores trailing garbage is not a successful parse. The
engine now enforces end-of-input after the final closing brace. The practical wrinkle: after pop
recoveries, orphaned closing braces legitimately remain, so in recovering mode brace-only trailing
debris after a recorded error is consumed silently instead of producing an error avalanche.

### 7. Recursive descent IS syntax-directed translation (§5.1 to §5.5)

The book's L-attributed scheme (inherited attributes flow down as parameters, synthesized
attributes flow up as return values, side effects in production order) is *literally* what a
disciplined recursive-descent parser does: one function per nonterminal, `inout` context, returned
values. The audit's final pass verified this correspondence function by function and found zero
deviations. Learning: there was no need for a separate "attribute evaluation" pass; the parser
already is one.

### 8. The chained symbol table is the ancestry model (§2.7)

The book's `Env` chaining (a scope's table points to its parent's) maps exactly onto xctemplate
`Ancestors` lineage: a template's referential integrity should be checked against the union of its
own definitions and its ancestors', walked in order. This is the documented deferral that will
extend referential integrity to the 6,610 ancestored templates.

### 9. Positions are part of the token, full stop

Every token carries 1-based line and column from birth. Everything downstream (syntax errors,
the positioned concrete syntax tree, the IDE's diagnostics) is only as good as this. Retrofitting
positions later would have touched every phase; carrying them from the start cost almost nothing.

### 10. Trees must survive recovery (learned while building, validated by §4.4.5)

The concrete syntax tree is built with begin/end node calls balanced by `defer`, so even a parse
that recovers five times yields a structurally sound (if partial) tree with correct spans. An IDE
cannot use a tree that collapses on the first error; the editor's outline must degrade, not vanish.

## Part 2: Engineering a Compiler (Cooper and Torczon, audit in progress)

### 11. Hand-coded scanners are the professional norm, not a shortcut (§2.5.3)

"An informal survey of commercial compiler groups found that a surprisingly large fraction used
hand-coded scanners"; gcc 4.0 included. The book treats table-driven, direct-coded, and hand-coded
scanners as equal citizens differing only in constant factors. Our hand-coded lexer is the
sanctioned engineering choice for a small token language, and the buffering machinery (double
buffering, fences) is irrelevant when the whole source is in memory.

### 12. Maximal munch is a rollback protocol, not just "be greedy" (§2.5, Fig 2.15)

The scanner must return the longest prefix that is a word, and when the DFA overshoots into a dead
end it must roll back to the most recent ACCEPTING state, restoring the input position. The classic
pathology `ab | (ab)*c` shows naive rollback going quadratic; the book's fix records failed
(state, position) pairs. Our token language cannot trigger the quadratic case, but the rollback
discipline produced two concrete audit items for the number lexer: a failed exponent tail
(`12e+` with no digit) must roll back BOTH the `e` and the sign, and a `#` that never opens a raw
string must be rolled back as a lone error character, not absorbed. Both are now pinned by tests
(see Part 3).

### 13. Two sanctioned keyword strategies, and we use the second (§2.5.4)

Either encode keywords in the DFA (more states, no lookup) or classify them as identifiers and
test against a table. We classify as IDENT and test by value at grammar positions that expect a
keyword. The book's blessing of this approach comes with the perfect-hashing aside: the test must
be cheap. Ours is a string comparison against at most five candidates at positions the grammar
already constrains; cheap enough.

### 14. FIRST+ is the cleanest statement of the backtrack-free condition (§3.3.1)

FIRST+(A -> beta) = FIRST(beta), extended with FOLLOW(A) when beta is nullable. A grammar is
backtrack free (predictive, LL(1)) exactly when alternatives of each nonterminal have pairwise
disjoint FIRST+ sets. This subsumes the Dragon Book's two-condition formulation into one test and
it is mechanically checkable from the tables. Action taken: `GRAMMAR.md` gets a FIRST+ table and
the disjointness check, so future grammar edits re-verify the property by inspection of one table
instead of re-deriving the argument.

### 15. Left recursion and left factoring are non-events for keyword-led grammars (§3.3.1, §3.5.4)

The grammar has no left recursion (every production is introduced by a distinct terminal) and
needs no left factoring (no two alternatives share a prefix). The learning is *why* this happened
for free: a bundle-description language where every construct announces itself by name is
naturally predictive. The book's stack-depth and associativity trade-offs (left vs right
recursion) apply to expression languages, not to ours; our lists are parsed iteratively, so the
right-recursion stack-depth concern does not arise either.

### 16. Context-sensitive ambiguity is resolved by exactly the trick we use (§3.5.3)

The FORTRAN `fee(i,j)` problem (array reference vs call) is the same shape as our unreserved
keywords: one token class, two meanings, resolved by context. The book's two solutions are (a)
defer to a later pass or (b) have scanner and parser handshake. We use a third variant the book
sanctions for recursive descent: the parser tests the IDENT's value at positions where the grammar
expects a construct keyword. Cheap, local, and the grammar stays unambiguous.

### 17. Error recovery via synchronizing words, stated plainly (§3.5.1)

The book's recovery story is the Dragon Book's in fewer words: pick synchronizing tokens, discard
input to one, reset state consistent with it, and make sure the driver does not run synthesis on a
broken parse. The last clause is the one worth quoting: "the error-recovery routines should take
steps to ensure that the compiler does not try to generate and optimize code for a syntactically
invalid program." That is our avalanche rule and the strict/recovering split: synthesis
(`compile`, `expand`) uses the strict parser; only analysis tolerates errors.

### 18. Ad hoc syntax-directed translation plus a central repository beats attribute copying (§4.4)

The book is candid that production compilers do not use formal attribute grammars; they attach
actions to productions and keep shared facts in a symbol table (the "central repository"),
because attribute grammars drown in copy rules. That is this engine's architecture stated from
first principles: parse actions build the bundle value, the metadata dictionary is the repository,
and the semantic validator walks the finished value. The C-declaration example (the grammar admits
what the standard forbids, and context-sensitive checking enforces the rest) is exactly our split:
the grammar admits any `let` key; the diagnostic validator enforces the vocabulary, the option
completeness rules, and referential integrity.

### 19. Parse tree, AST, DAG: pick the level of abstraction deliberately (§5.2.1)

The parse tree records the whole derivation; the AST contracts it by dropping nonterminal chaff;
a DAG shares identical subtrees. The engine deliberately keeps TWO trees: the positioned concrete
syntax tree (for the IDE: outline, folding, diagnostics anchors) and the semantic bundle value
(the "AST" the synthesis side consumes). The book's R^n war story (one bloated node type for
everything, 75 percent size reduction after auditing fields) is the warning that justifies keeping
them separate instead of growing one tree that serves both masters badly. Its other lesson,
"S-expressions are essentially ASTs", is a reminder that our decompiled DSL text is itself a
serialization of the AST, which is why print-then-parse inversion is a meaningful gate.

### 20. The editing-oriented AST differs from the compiling-oriented AST (§5.2.1 sidebar)

The R^n complex-constant example: `(c1, c2)` as a `pair` node was right for the editor and wrong
for the compiler. This is the cleanest justification in print for the TemplatoIDE seam decision
that `OutlineNode` (editor view) and the engine's internal trees are distinct types bridged by an
adapter, rather than one shared tree.

## Part 3: Audit items raised by Part 2, and their resolution

| Item | Source | Check | Outcome |
|---|---|---|---|
| A1: failed exponent tail must roll back sign and `e` | §2.5 Fig 2.15 | `12e+` / `12E+y` / `3.5e` keep the NUMBER and surrender every overshot character | already conformant by construction (lookahead-before-commit); pinned by `LexerTests` "failed exponent tail" |
| A2: `#` that never opens `#"` must not be absorbed | §2.5 Fig 2.15 | bare `#` yields one recovered lexical error per character, lexing continues | already conformant (hash counting is pure lookahead; no-quote falls to panic-mode deletion); pinned by `LexerTests` hash tests |
| A3: FIRST+ table with pairwise-disjointness | §3.3.1 | table present in `GRAMMAR.md`, every nonterminal's alternatives disjoint | added to `GRAMMAR.md`; all rows disjoint |
| A4: epsilon decisions must reject junk, not skip it | §3.3.1 | a non-FIRST, non-FOLLOW token inside a body produces a positioned error | verified: `42` inside a template body reports `2:5: error: unexpected token '42'`, exit 1 |

The first audit pass against this book therefore found ZERO code defects: the Dragon Book pass had
already forced the same disciplines. The pass still produced artifacts (two pinned lexer behaviors
that were previously accidental, one formal table that was previously an argument), which is the
difference between being correct and staying correct.

Resolution of each item is corpus-gated like everything else: after any lexer or parser change,
all four gates must print `RESULT: PASS` over the full corpus.

## Part 4: Cross-book synthesis

- Both books converge on the same front-end shape: predictive recursive descent over a grammar
  with computed FIRST/FOLLOW, errors recovered at synchronizing tokens, semantics as actions plus
  a central table. Where they differ is emphasis: the Dragon Book proves, Cooper and Torczon
  engineer. Reading both caught different bugs: the Dragon Book's Fig 4.22 exposed the pop-action
  gap; Engineering a Compiler's Fig 2.15 exposed the rollback gaps.
- The strongest shared lesson: every "obvious" hand-written decision (a lookahead test, a greedy
  scan, an epsilon exit) corresponds to a formal object (a FIRST+ row, an accepting state, a
  FOLLOW membership). Writing the formal object down converts folklore into a checkable artifact,
  and the corpus turns the check into proof.
- What neither book covers and the corpus taught alone: byte-exact round-tripping as an
  acceptance criterion, spelling preservation (a serializer is part of the language), and using
  10,117 real artifacts as the test oracle. The books supply the discipline; the corpus supplies
  the truth.
