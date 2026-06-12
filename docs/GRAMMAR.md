# The XCTemplateDSL Grammar

The formal grammar of `.xctdsl`, with its FIRST and FOLLOW sets, the LL(1) argument, and the derived
panic-mode synchronizing sets. This is the Dragon Book discipline (Aho, Lam, Sethi, Ullman, 2nd ed.,
sections 4.2 to 4.4) applied to this language: the parser in `Sources/Parser/Parser.swift` is the
recursive-descent realization of exactly these productions, and its error-recovery sets are derived from
the tables below, not hand-picked.

## Tokens (terminals)

Produced by `Sources/Lexer/Lexer.swift`. Each token carries its 1-based line and column.

| Token | Lexeme pattern |
|---|---|
| `let` | the keyword `let` |
| IDENT | `[A-Za-z_][A-Za-z0-9_]*` except `let`, `true`, `false` |
| BOOLEAN | `true` or `false` |
| NUMBER | `-? digits ( . digits )? ( [eE] [+-]? digits )?` (maximal munch; a trailing `.` or `e` is not consumed) |
| STRING | `"…"` with `\n \t \r \" \\` escapes, or raw `#"…"#` (no escapes, hashes balance) |
| MULTISTRING | `"""…"""` / `#"""…"""#`, Swift multi-line semantics (first and last newline stripped, closing-line indentation removed) |
| `{` `}` `[` `]` `:` `=` `,` | punctuation |

Comments (`// …`, `/* … */`) and whitespace separate tokens and are discarded (section 3.1.1). An
editor-grade trivia-preserving mode is future work, noted in the backlog.

Keywords `option`, `unit`, `node`, `directory`, `template` are NOT reserved: they reach the parser as
IDENT and disambiguate by value at positions where the grammar expects them. This keeps them usable as
dictionary keys and plist key names.

## Productions

```
Template      -> 'template' STRING '{' Items '}'
Items         -> Item Items | epsilon
Item          -> LetBinding | Option | Node | Directory
LetBinding    -> 'let' Key '=' Value
Key           -> IDENT | STRING | BOOLEAN
Option        -> 'option' STRING '{' OptionItems '}'
OptionItems   -> OptionItem OptionItems | epsilon
OptionItem    -> LetBinding | Unit
Unit          -> 'unit' STRING '{' UnitItems '}'
UnitItems     -> UnitItem UnitItems | epsilon
UnitItem      -> LetBinding | Node
Node          -> 'node' STRING '{' NodeItems '}'
NodeItems     -> LetBinding NodeItems | epsilon
Directory     -> 'directory' STRING
Value         -> STRING | MULTISTRING | NUMBER | BOOLEAN | Array | Dict
Array         -> '[' Elements ']'
Elements      -> Value MoreElements | epsilon
MoreElements  -> ',' Value MoreElements | epsilon
Dict          -> '{' Pairs '}'
Pairs         -> Pair MorePairs | epsilon
MorePairs     -> ',' Pair MorePairs | epsilon
Pair          -> DictKey ':' Value
DictKey       -> IDENT | STRING
```

A NUMBER with a fractional part or exponent yields a real; otherwise an integer (an integer too large
for `Int` falls back to real). The `_isArray`, `_isEmptyArray`, and `_isString` let-keys inside units and
nodes are authoring markers consumed by the semantic deriver, not part of the plist vocabulary.

Plist value coverage (corpus-proven 2026-06): all 10,117 shipped manifests contain zero `<real>`,
`<date>`, and `<data>` values. Reals are nevertheless supported end to end (model, lexer, parser,
decompiler) so a user-authored template cannot be silently truncated (the previous behavior turned
`<real>3.14</real>` into `<integer>3</integer>`). Dates and data have no DSL literal and remain a
documented limitation with zero corpus impact.

## FIRST sets (section 4.4.2, computed by the three rules)

| Nonterminal | FIRST |
|---|---|
| Template | { `template` } |
| Item | { `let`, `option`, `node`, `directory` } |
| Items | FIRST(Item) plus epsilon |
| LetBinding | { `let` } |
| Option | { `option` } |
| OptionItem | { `let`, `unit` } |
| Unit | { `unit` } |
| UnitItem | { `let`, `node` } |
| Node | { `node` } |
| NodeItems | { `let` } plus epsilon |
| Directory | { `directory` } |
| Value | { STRING, MULTISTRING, NUMBER, BOOLEAN, `[`, `{` } |

## FOLLOW sets (section 4.4.2, rules 1 to 3)

| Nonterminal | FOLLOW |
|---|---|
| Template | { $ } |
| Items / Item | { `}` } / FIRST(Item) plus { `}` } |
| OptionItems / OptionItem | { `}` } / { `let`, `unit`, `}` } |
| UnitItems / UnitItem | { `}` } / { `let`, `node`, `}` } |
| NodeItems | { `}` } |
| LetBinding | union of the item FOLLOWs where it appears: { `let`, `option`, `node`, `directory`, `unit`, `}` } |
| Value | FOLLOW(LetBinding) plus { `,`, `]`, `}` } |

## LL(1) argument (section 4.4.3)

For every nonterminal with alternatives, the alternatives' FIRST sets are pairwise disjoint: each item
form opens with a distinct keyword or token class (the book's observation that keyword-guided constructs
generally satisfy LL(1)), `Value` alternatives open with distinct token types, and the only shared
opener, `{` for both a block and a Dict, never occurs at the same decision point (Dict appears only in
value position). No production is left-recursive (lists are right-recursive via the loop form), and no
alternative pair needs left factoring. The parser therefore never backtracks: one token of lookahead
chooses every production, which is what makes the concrete syntax tree buildable in a single pass
alongside the semantic model (section 5.5, L-attributed evaluation during recursive-descent parsing).

## FIRST+ sets and the backtrack-free condition (Cooper and Torczon, section 3.3.1)

Engineering a Compiler states the LL(1) property as one mechanical test. For a production
A -> beta, FIRST+(A -> beta) is FIRST(beta), extended with FOLLOW(A) when beta can derive epsilon.
A grammar is backtrack free exactly when, for every nonterminal, the FIRST+ sets of its
alternatives are pairwise disjoint. The table lists every nonterminal with more than one
alternative; epsilon rows use the FOLLOW sets above.

| Nonterminal | Alternative | FIRST+ |
|---|---|---|
| Item | LetBinding / Option / Node / Directory | { `let` } / { `option` } / { `node` } / { `directory` } |
| Items | Item Items / epsilon | { `let`, `option`, `node`, `directory` } / { `}` } |
| OptionItem | LetBinding / Unit | { `let` } / { `unit` } |
| OptionItems | OptionItem OptionItems / epsilon | { `let`, `unit` } / { `}` } |
| UnitItem | LetBinding / Node | { `let` } / { `node` } |
| UnitItems | UnitItem UnitItems / epsilon | { `let`, `node` } / { `}` } |
| NodeItems | LetBinding NodeItems / epsilon | { `let` } / { `}` } |
| Key | IDENT / STRING / BOOLEAN | one distinct token type each |
| Value | STRING / MULTISTRING / NUMBER / BOOLEAN / Array / Dict | distinct token types; `[` / `{` |
| Elements | Value MoreElements / epsilon | FIRST(Value) / { `]` } |
| MoreElements | `,` Value MoreElements / epsilon | { `,` } / { `]` } |
| Pairs | Pair MorePairs / epsilon | { IDENT, STRING } / { `}` } |
| MorePairs | `,` Pair MorePairs / epsilon | { `,` } / { `}` } |
| DictKey | IDENT / STRING | one distinct token type each |

Every row is pairwise disjoint, so the grammar is backtrack free in the FIRST+ formulation as well
as the Dragon Book's two-condition formulation above. The keyword rows rely on the value test (the
keywords are unreserved IDENTs disambiguated by value at keyword positions), which Cooper and
Torczon sanction for hand-coded recursive descent in sections 3.3.2 and 3.5.3. Any grammar edit
must keep every row of this table disjoint; a collision means the new construct needs a
distinguishing opener or a left-factoring.

## Panic-mode synchronizing sets (sections 4.1.4 and 4.4.5, Fig. 4.22 semantics)

Derived from the tables above. On an error inside construct A, the parser skips tokens until:

- a RESUME token: FIRST(A's item) plus `}` (the construct's own FOLLOW boundary), then continues A's loop;
- a POP token: a starter that cannot begin an item of A but begins an item of an ENCLOSING construct
  (the book's heuristic 2). A is then closed where it stands and control returns to the enclosing loop,
  which parses the token correctly. Without the pop action, the enclosing construct's content would be
  silently mis-attached into A, which is worse than the error itself.

| Construct being recovered | RESUME on | POP on |
|---|---|---|
| Template body item | `let`, `option`, `node`, `directory`, `}` | (none: top level) |
| Option body item | `let`, `unit`, `}` | `option`, `node`, `directory` |
| Unit body item | `let`, `node`, `}` | `unit`, `option`, `directory` |
| Node binding (both node forms) | `let`, `}` | `node`, `unit`, `option`, `directory` |

Termination: every recovery consumes at least one token (the progress guard), the book's condition for
panic mode being free of infinite loops. Lexical recovery (section 3.1.4) is panic-mode character
deletion with the error recorded; an unterminated string yields its partial lexeme.

## Acceptance check

```sh
cd ../XCTemplateDSLCLI && swift build -c release && cd ../XCTemplateDSL
swift scripts/check-corpus.swift all     # MUST print RESULT: PASS
```

All four gates (roundtrip, check, ast, expand) over the whole corpus of 10,117 templates. Any change to
this grammar or its parser must keep that PASS and update this document in the same change.
