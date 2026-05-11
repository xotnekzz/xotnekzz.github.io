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
DOCS = ROOT / "docs"
MEMORY = ROOT / "memory"
AGENTS = ROOT / "AGENTS.md"
TECHDEBT = ROOT / ".harness" / "tracks" / "tech-debt-tracker.md"

LINK_RE = re.compile(r"\]\(([^)]+\.md)\)")


def find_orphans() -> list[str]:
    """docs/ 하위 파일 중 어떤 index.md에서도 링크되지 않은 것."""
    if not DOCS.exists():
        return []
    linked: set[Path] = set()
    for idx in DOCS.rglob("index.md"):
        base = idx.parent
        for m in LINK_RE.findall(idx.read_text(encoding="utf-8")):
            target = (base / m).resolve()
            linked.add(target)
    orphans: list[str] = []
    for f in DOCS.rglob("*.md"):
        if f.name == "index.md":
            continue
        if f.resolve() not in linked:
            orphans.append(str(f.relative_to(ROOT)))
    return orphans


def agents_md_pressure() -> tuple[int, bool]:
    if not AGENTS.exists():
        return 0, False
    n = sum(1 for _ in AGENTS.open(encoding="utf-8"))
    return n, n > 80


def stale_memory(days: int = 180) -> list[str]:
    if not MEMORY.exists():
        return []
    now = datetime.now(timezone.utc).timestamp()
    cutoff = now - days * 86400
    out: list[str] = []
    for f in MEMORY.glob("project_*.md"):
        if f.stat().st_mtime < cutoff:
            out.append(str(f.relative_to(ROOT)))
    return out


def main() -> int:
    report = {
        "generated": datetime.now(timezone.utc).isoformat(),
        "orphan_docs": find_orphans(),
        "agents_md": dict(zip(("lines", "near_cap"), agents_md_pressure())),
        "stale_project_memory": stale_memory(),
    }
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
