#!/usr/bin/env python3
"""Generate MockCorpus.json entirely from the real cupertino index.

This drives the installed `cupertino` binary. Nothing is invented:

  1. Fan-out `search` discovers real document URIs across apple-docs, packages,
     swift-evolution, and samples.
  2. Targeted per-source `search` covers the sources fan-out does not surface
     (hig, swift-org, swift-book, apple-archive).
  3. `read <uri> --format markdown` fetches each document's full body verbatim.
  4. Framework counts come from `list-frameworks`.

Every title, summary, body, availability, and framework count is real index
data. Run from the repo root:

    python3 scripts/build-mock-corpus.py

Override the binary with CUPERTINO_BIN if it is not at the Homebrew default.
"""

import json
import os
import re
import subprocess

BIN = os.environ.get("CUPERTINO_BIN", "/opt/homebrew/bin/cupertino")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Packages/Sources/MobileBackendImpl/Resources/MockCorpus.json")

# The binary prints an ISO-8601 log timestamp on stdout before its payload.
TIMESTAMP = re.compile(r"^\s*\d{4}-\d{2}-\d{2}T[\d:+\-]+\s*")
# Crawler titles carry a site suffix, with or without spaces around the pipe.
TITLE_SUFFIX = re.compile(r"\s*\|\s*Apple ?Developer ?Documentation\s*$", re.IGNORECASE)

# Fan-out queries (cover apple-docs, packages, swift-evolution, samples).
FANOUT_QUERIES = [
    "view", "animation", "navigation", "layout stack", "text formatting",
    "data storage", "button styles", "accessibility", "gestures", "concurrency actor",
    "async await", "property wrapper", "networking", "table view", "image loading",
    "state management", "core animation", "swift package manager", "charts", "maps",
]

# Sources fan-out does not surface, each with a few diverse queries.
PER_SOURCE_QUERIES = {
    "hig": ["layout", "navigation", "color", "typography", "buttons", "accessibility", "data entry"],
    "swift-org": ["docc documentation", "package manager", "concurrency", "testing", "evolution"],
    "swift-book": ["closures", "optionals", "protocols", "generics", "concurrency", "enumerations"],
    "apple-archive": ["auto layout", "core animation", "quartz", "key value observing", "drawing"],
}

# Per-source document caps so the bundle stays a sensible size.
CAPS = {
    "apple-docs": 32,
    "swift-evolution": 22,
    "packages": 16,
    "samples": 12,
    "hig": 16,
    "swift-org": 16,
    "swift-book": 14,
    "apple-archive": 12,
}

# Well-known frameworks to surface in the browser even if no captured doc names
# them; counts are still looked up from the real index (absent names are dropped).
CURATED_FRAMEWORKS = [
    "swiftui", "uikit", "appkit", "foundation", "combine", "swiftdata", "coredata",
    "mapkit", "avfoundation", "cloudkit", "widgetkit", "charts", "spritekit", "scenekit",
    "realitykit", "metal", "coreml", "createml", "vision", "naturallanguage",
    "networkextension", "storekit", "healthkit", "homekit", "watchkit", "corelocation",
    "photokit", "passkit", "usernotifications", "swift-org", "swift-book",
]


def cup(*args):
    """Run the binary and return stdout with the log-timestamp prefix stripped."""
    result = subprocess.run([BIN, *args], capture_output=True, text=True)
    return TIMESTAMP.sub("", result.stdout)


def cup_json(*args):
    raw = cup(*args)
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def clean_title(title):
    if not title:
        return ""
    return TITLE_SUFFIX.sub("", title).strip()


def availability_from(record):
    """Map the index's availability array into {platform: introducedVersion}."""
    entries = record.get("availability")
    if not isinstance(entries, list):
        return None
    floor = {}
    for entry in entries:
        name, version = entry.get("name"), entry.get("introducedAt")
        if name and version:
            floor[name] = version
    return floor or None


def main():
    collected = {}  # uri -> partial record (no body yet)

    def add(uri, source, framework, title, summary, availability):
        if not uri or not source or uri in collected:
            return
        collected[uri] = {
            "uri": uri,
            "source": source,
            "framework": (framework or source).lower(),
            "title": clean_title(title) or uri,
            "summary": (summary or "").strip()[:300],
            "availability": availability,
        }

    # 1. Fan-out discovery.
    for query in FANOUT_QUERIES:
        payload = cup_json("search", query, "--limit", "20", "--include-archive", "--format", "json")
        if not payload:
            continue
        for candidate in payload.get("candidates", []):
            metadata = candidate.get("metadata", {})
            add(
                candidate.get("identifier"), candidate.get("source"), metadata.get("framework"),
                candidate.get("title"), candidate.get("chunk"), None,
            )

    # 2. Per-source discovery for the sources fan-out misses.
    for source, queries in PER_SOURCE_QUERIES.items():
        for query in queries:
            payload = cup_json("search", query, "--source", source, "--limit", "20", "--format", "json")
            if payload is None:
                continue
            rows = payload if isinstance(payload, list) else (payload.get("results") or [])
            for row in rows:
                add(
                    row.get("uri"), row.get("source", source), row.get("framework", source),
                    row.get("title"), row.get("summary"), availability_from(row),
                )

    # 3. Apply per-source caps, preserving discovery order.
    per_source_count = {}
    capped = []
    for record in collected.values():
        source = record["source"]
        cap = CAPS.get(source, 12)
        if per_source_count.get(source, 0) >= cap:
            continue
        per_source_count[source] = per_source_count.get(source, 0) + 1
        capped.append(record)

    # 4. Read each document's full body verbatim.
    documents = []
    for record in capped:
        body = cup("read", record["uri"], "--source", record["source"], "--format", "markdown").strip("\n")
        if not body:
            continue
        document = {
            "uri": record["uri"],
            "source": record["source"],
            "framework": record["framework"],
            "title": record["title"],
            "summary": record["summary"],
            "markdown": body,
        }
        if record["availability"]:
            document["availability"] = record["availability"]
        documents.append(document)
        print(f"  read {record['uri']} ({len(body)} chars)")

    # 5. Frameworks: union of captured frameworks and the curated set, real counts only.
    framework_list = cup_json("list-frameworks", "--format", "json") or []
    counts = {item["name"].lower(): item["documentCount"] for item in framework_list}
    names = {doc["framework"] for doc in documents} | set(CURATED_FRAMEWORKS)
    frameworks = sorted(
        ({"id": name, "count": counts[name]} for name in names if name in counts),
        key=lambda entry: -entry["count"],
    )

    corpus = {"frameworks": frameworks, "documents": documents}
    with open(OUT, "w", encoding="utf-8") as handle:
        json.dump(corpus, handle, indent=2, ensure_ascii=False)
        handle.write("\n")

    by_source = {}
    for doc in documents:
        by_source[doc["source"]] = by_source.get(doc["source"], 0) + 1
    print(f"\nwrote {OUT}")
    print(f"  {len(frameworks)} frameworks, {len(documents)} documents")
    print("  by source: " + ", ".join(f"{src}={n}" for src, n in sorted(by_source.items())))


if __name__ == "__main__":
    main()
