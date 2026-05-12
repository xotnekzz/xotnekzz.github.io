#!/usr/bin/env python3
"""doc-gardener의 스캔 엔진. PR을 열지는 않고, 드리프트 보고서만 출력.

.github/workflows/doc-gardener.yml에서 호출 → 보고서를 이슈/PR 본문으로 포스팅.
"""
from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / ".harness" / "docs"
TRACKS = ROOT / ".harness" / "tracks"
TRACK_INDEX = ROOT / ".harness" / "Track.md"
AGENTS = ROOT / "AGENTS.md"
TECHDEBT = ROOT / ".harness" / "docs" / "tech-debt-tracker.md"

LINK_RE = re.compile(r"\]\(([^)]+\.md)\)")


def find_orphan_tracks() -> list[str]:
    """tracks/*.md 중 Track.md에서 링크되지 않은 것."""
    if not TRACKS.exists() or not TRACK_INDEX.exists():
        return []
    index_text = TRACK_INDEX.read_text(encoding="utf-8")
    orphans: list[str] = []
    for f in TRACKS.glob("*.md"):
        if f.name == "_template.md":
            continue
        if f.name not in index_text:
            orphans.append(str(f.relative_to(ROOT)))
    return orphans


def agents_md_pressure() -> tuple[int, bool]:
    if not AGENTS.exists():
        return 0, False
    n = sum(1 for _ in AGENTS.open(encoding="utf-8"))
    return n, n > 80


def main() -> int:
    report = {
        "generated": datetime.now(timezone.utc).isoformat(),
        "orphan_tracks": find_orphan_tracks(),
        "agents_md": dict(zip(("lines", "near_cap"), agents_md_pressure())),
    }
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
