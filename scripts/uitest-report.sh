#!/usr/bin/env bash
# Run the POM/FlowSpec UI-test suite across every distinct UI target, then render one
# Apple-styled HTML report grouped by target.
#
# Each app runs the same declarative scenarios (scenarios/*.json) through the shared page
# objects (UITestPageObjects) over the deterministic embedded corpus: the mobile apps use
# their mock backend by default, the desktop apps take the `-uitest-mock` launch argument
# (so the suite runs offline, without a live `cupertino serve`). Results are extracted from
# each xcresult and rendered by the Swift FlowSpecReportTool.
#
# Output lands in test-reports/ (git-ignored). Pass an alternate output dir as $1.
#
# Requires: Xcode, an available "iPhone 17" simulator, XcodeGen-generated projects
# (run scripts/generate-xcodeproj.sh first).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/test-reports}"
XCRESULTS="$OUT/xcresults"
DERIVED="${DERIVED_DATA:-/tmp/cupertino-uitest-dd}"

mkdir -p "$OUT"
rm -rf "$XCRESULTS"
mkdir -p "$XCRESULTS"

IOS_DEST='platform=iOS Simulator,name=iPhone 17'
MAC_DEST='platform=macOS'

run() { # scheme destination
    echo "==> Testing $1"
    # A scheme with failing tests must not abort the whole run; the report records it.
    xcodebuild test \
        -workspace "$ROOT/Main.xcworkspace" \
        -scheme "$1" \
        -destination "$2" \
        -resultBundlePath "$XCRESULTS/$1.xcresult" \
        -derivedDataPath "$DERIVED" \
        >/dev/null 2>&1 || echo "    (scheme $1 reported test failures)"
}

run CupertinoMobileSwiftUI "$IOS_DEST"
run CupertinoMobileUIKit "$IOS_DEST"
run CupertinoDesktopSwiftUI "$MAC_DEST"
run CupertinoDesktopAppKit "$MAC_DEST"

echo "==> Extracting scenario results"
python3 "$ROOT/scripts/uitest-extract.py" "$ROOT/scenarios" "$XCRESULTS" "$OUT/results.json"

echo "==> Rendering report"
swift run --package-path "$ROOT/Packages" FlowSpecReportTool "$OUT/results.json" "$OUT/index.html"

echo "==> Report: $OUT/index.html"
