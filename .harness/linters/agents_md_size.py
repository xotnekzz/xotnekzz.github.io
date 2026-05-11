#!/usr/bin/env python3
"""Enforce AGENTS.md ≤ 100 lines. Warn if docs/*.md > 500 lines."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AGENTS_MAX = 100
DOC_MAX = 500


def line_count(p: Path) -> int:
    return sum(1 for _ in p.open(encoding="utf-8"))


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    for name in ("AGENTS.md", "CLAUDE.md", "GEMINI.md"):
        f = ROOT / name
        if not f.exists():
            continue
        n = line_count(f)
        if n > AGENTS_MAX:
            errors.append(f"{name}: {n} lines > {AGENTS_MAX} (hard cap). Extract to docs/.")

    docs = ROOT / "docs"
    if docs.exists():
        for f in docs.rglob("*.md"):
            n = line_count(f)
            if n > DOC_MAX:
                rel = f.relative_to(ROOT)
                warnings.append(f"{rel}: {n} lines > {DOC_MAX} (warn). Consider splitting.")

    for w in warnings:
        print(f"warn: {w}", file=sys.stderr)
    for e in errors:
        print(f"error: {e}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
