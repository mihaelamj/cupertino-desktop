#!/usr/bin/env bash
# Namespacing gate (docs/rules/code-style.md): one non-private top-level type per
# file. A file with more than one file-scope type declaration is a violation:
# split it, or mark helper types private/fileprivate.
#
# Inert until Packages/Sources exists. Portable: bash 3.2 and 4+.

set -u

SRC="Packages/Sources"
if [ ! -d "$SRC" ]; then
  echo "namespacing: no $SRC yet, skipping."
  exit 0
fi

FAIL=0
while IFS= read -r f; do
  count=$(grep -cE "^(public |package |internal )?(actor|struct|enum|protocol|class|final class) [A-Z]" "$f")
  if [ "$count" -gt 1 ]; then
    echo "namespacing: $count file-scope types in $f (one per file)" >&2
    FAIL=1
  fi
done < <(find "$SRC" -name "*.swift")

if [ "$FAIL" -ne 0 ]; then
  echo "namespacing: gate failed. Rule: docs/rules/code-style.md" >&2
fi
exit "$FAIL"
