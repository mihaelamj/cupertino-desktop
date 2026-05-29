#!/usr/bin/env bash
# Regenerate the per-app Xcode projects from their project.yml manifests.
# The .xcodeproj bundles are generated artifacts (git-ignored); project.yml is
# the committed source of truth. Run this after a fresh clone before opening
# Main.xcworkspace, or whenever an app's project.yml changes.
#
# Requires XcodeGen: `brew install xcodegen`.

set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen not found. Install it with: brew install xcodegen" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for app in CupertinoDesktopSwiftUI CupertinoDesktopAppKit CupertinoMobile; do
  echo "Generating $app.xcodeproj"
  xcodegen generate --spec "$ROOT/Apps/$app/project.yml" --project "$ROOT/Apps/$app"
done

echo "Done. Open Main.xcworkspace and pick a scheme."
