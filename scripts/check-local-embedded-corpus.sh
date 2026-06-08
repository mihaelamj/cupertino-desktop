#!/usr/bin/env bash
# Read-only smoke for the embedded backend over a real Cupertino corpus.
# Defaults to ~/.cupertino, or set CUPERTINO_DESKTOP_EMBEDDED_CORPUS.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORPUS="${CUPERTINO_DESKTOP_EMBEDDED_CORPUS:-$HOME/.cupertino}"

if [ ! -d "$CORPUS" ]; then
  echo "embedded-corpus: missing corpus directory: $CORPUS" >&2
  echo "embedded-corpus: set CUPERTINO_DESKTOP_EMBEDDED_CORPUS to a Cupertino corpus bundle" >&2
  exit 1
fi

cd "$ROOT/Packages"
CUPERTINO_DESKTOP_EMBEDDED_INTEGRATION=1 \
CUPERTINO_DESKTOP_EMBEDDED_CORPUS="$CORPUS" \
swift test --filter "liveEmbeddedRealCorpusSmoke"
