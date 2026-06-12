#!/usr/bin/env bash
# Scan commit MESSAGES in a range for AI-attribution tells. Tool-agnostic.
#
# Complements scripts/check-style.sh, which scans tracked FILE CONTENT via
# `git ls-files` and therefore never sees commit messages. An attribution
# trailer (e.g. "Co-authored-by: Cursor") lives in the message, not a file, so
# without this scan a poisoned trailer reaches the remote with no CI backstop.
#
# This is the merge-time backstop for github-discipline.md Rule 5.1; the local
# .githooks/commit-msg hook is the write-time backstop. Some assistants re-add a
# trailer on every commit/amend even when told not to, so neither the per-tool
# setting nor discipline alone is enough.
#
# Usage:
#   scripts/check-commit-attribution.sh [<range>]
# Range resolution (first that applies):
#   1) explicit "<range>" argument (e.g. origin/main..HEAD)
#   2) BASE_SHA and HEAD_SHA environment variables -> BASE_SHA..HEAD_SHA
#   3) fallback: just HEAD (single commit)
#
# Portable: BSD-compatible grep, bash 3.2 (macOS) and bash 4+ (CI).

set -u

RANGE="${1:-}"
if [ -z "$RANGE" ]; then
  if [ -n "${BASE_SHA:-}" ] && [ -n "${HEAD_SHA:-}" ]; then
    RANGE="${BASE_SHA}..${HEAD_SHA}"
  else
    RANGE="HEAD~0..HEAD"
  fi
fi

# Resolve the commit list. If the range is unusable (shallow clone, unknown
# base), fall back to HEAD so we always scan at least the tip.
COMMITS=$(git rev-list "$RANGE" 2>/dev/null || true)
[ -z "$COMMITS" ] && COMMITS=$(git rev-parse HEAD)

# Tool-agnostic AI-attribution detection (attribution-context only, so prose
# that merely contains a tool word is not a false positive). Mirrors
# .githooks/commit-msg and scripts/check-style.sh.
AI_TOOLS='Claude|Anthropic|Codex|OpenAI|ChatGPT|GPT-[0-9]|Cursor|Copilot|Gemini|Google AI'
ATTRIB_REGEX="^(Co-Authored-By|Co-authored-with|Generated (with|by)|Created (with|by)|Powered by|with help from|written by|authored by)[: ].*(${AI_TOOLS})"

GENERIC_PATTERNS=(
  'as an AI'
  'this commit was generated'
  'this change was generated'
)

# AI-tell signature emojis, kept as bytes so this file carries no glyphs.
EMOJI_TELLS=$(printf '\xf0\x9f\xa4\x96\n\xe2\x9c\xa8\n\xf0\x9f\xaa\x84\n\xf0\x9f\xa7\xa0\n\xf0\x9f\xa6\xbe\n\xf0\x9f\xa4\x9d')
EMDASH=$(printf '\xe2\x80\x94')

FAIL=0
for sha in $COMMITS; do
  MSG=$(git log -1 --format='%B' "$sha")
  short=$(git rev-parse --short "$sha")

  # Attribution trailer/phrase, anchored to line start so a body sentence that
  # describes the trailer (documentation) is not flagged, only a real trailer.
  if printf '%s\n' "$MSG" | grep -qiE -- "$ATTRIB_REGEX"; then
    printf 'commit-attribution: %s names an AI tool/vendor in attribution context.\n' "$short" >&2
    printf '%s\n' "$MSG" | grep -niE -- "$ATTRIB_REGEX" | sed 's/^/    /' >&2
    FAIL=1
  fi

  for p in "${GENERIC_PATTERNS[@]}"; do
    if printf '%s' "$MSG" | grep -qiF -- "$p"; then
      printf 'commit-attribution: %s contains forbidden phrase: %s\n' "$short" "$p" >&2
      FAIL=1
    fi
  done

  if LC_ALL=C printf '%s' "$MSG" | grep -qF -- "$EMDASH"; then
    printf 'commit-attribution: %s contains an em dash (U+2014).\n' "$short" >&2
    FAIL=1
  fi

  while IFS= read -r emoji; do
    [ -z "$emoji" ] && continue
    if LC_ALL=C printf '%s' "$MSG" | grep -qF -- "$emoji"; then
      printf 'commit-attribution: %s contains an AI-signature emoji.\n' "$short" >&2
      FAIL=1
      break
    fi
  done <<<"$EMOJI_TELLS"
done

if [ "$FAIL" -ne 0 ]; then
  printf 'commit-attribution: gate failed. Rule: github-discipline.md Rule 5.1 / 5.2 (tool-agnostic).\n' >&2
  printf '  Rebuild the offending commit with a clean message (git commit-tree bypasses\n' >&2
  printf '  any assistant trailer injection), then re-push.\n' >&2
fi
exit "$FAIL"
