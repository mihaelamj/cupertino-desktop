#!/usr/bin/env python3
"""Extract FlowSpec scenario outcomes from xcodebuild `.xcresult` bundles into the
`[ScenarioResult]` JSON that the Swift `FlowSpecReportTool` renders.

The scenario titles and step counts come from the `scenarios/*.json` files (the single
source of truth the apps run); pass/fail, duration, and the failure message come from the
xcresult. Each result is tagged with the UI target it ran against so the report groups by it.

Usage:
    uitest-extract.py <scenarios-dir> <xcresults-dir> <out.json>

`<xcresults-dir>` holds one `<Scheme>.xcresult` per UI target. Schemes are mapped to the
display label used in the report below.
"""
import json
import subprocess
import sys
from pathlib import Path

# Scheme (xcresult file stem) -> report group label.
TARGET_LABELS = {
    "CupertinoMobileSwiftUI": "Mobile SwiftUI",
    "CupertinoMobileUIKit": "Mobile UIKit",
    "CupertinoDesktopSwiftUI": "Desktop SwiftUI",
    "CupertinoDesktopAppKit": "Desktop AppKit",
}

# UITest method -> scenario id (scenarios/<id>.json). POM tests carry no scenario file and
# are not part of the FlowSpec report.
METHOD_TO_SCENARIO = {
    "testFrameworkReaderScenario": "framework-reader",
    "testReaderTextSizeScenario": "reader-text-size",
    "testDefaultSelectionScenario": "default-selection",
    "testFrameworkSearchSortScenario": "framework-search-sort",
}


def test_cases(xcresult: Path):
    """Yield every Test Case node from an xcresult's test-results tree."""
    raw = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "tests",
         "--path", str(xcresult), "--format", "json"],
        capture_output=True, text=True, check=True,
    ).stdout
    tree = json.loads(raw)

    def walk(node):
        for child in node.get("children", []):
            yield from walk(child)
        if node.get("nodeType") == "Test Case":
            yield node

    for root in tree.get("testNodes", []):
        yield from walk(root)


def failure_of(node):
    for child in node.get("children", []):
        if child.get("nodeType") in ("Failure Message", "Failure"):
            return child.get("name")
    return None


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    scenarios_dir, xcresults_dir, out_path = (Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]))

    results = []
    for scheme, label in TARGET_LABELS.items():
        xcresult = xcresults_dir / f"{scheme}.xcresult"
        if not xcresult.exists():
            print(f"skip: {xcresult} not found", file=sys.stderr)
            continue
        for case in test_cases(xcresult):
            method = case.get("name", "").removesuffix("()")
            scenario_id = METHOD_TO_SCENARIO.get(method)
            if scenario_id is None:
                continue  # not a FlowSpec scenario (e.g. a Page Object Model test)
            spec = json.loads((scenarios_dir / f"{scenario_id}.json").read_text())
            results.append({
                "uiTarget": label,
                "id": scenario_id,
                "title": spec["title"],
                "stepCount": len(spec["steps"]),
                "passed": case.get("result") == "Passed",
                "failure": failure_of(case),
                "duration": case.get("durationInSeconds", 0.0),
            })

    results.sort(key=lambda r: (list(TARGET_LABELS.values()).index(r["uiTarget"]), r["id"]))
    out_path.write_text(json.dumps(results, indent=2))
    passed = sum(1 for r in results if r["passed"])
    print(f"Wrote {out_path} ({passed}/{len(results)} scenarios passed across {len(TARGET_LABELS)} UI targets)")


if __name__ == "__main__":
    main()
