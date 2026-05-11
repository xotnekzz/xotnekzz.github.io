#!/usr/bin/env python3
"""Validate memory/ frontmatter schema and MEMORY.md index integrity."""
from __future__ import annotations

import re
import sys
from pathlib import Path

VALID_TYPES = {"user", "feedback", "project", "reference"}
FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
INDEX_LINK_RE = re.compile(r"\]\(([^)]+\.md)\)")

ROOT = Path(__file__).resolve().parents[2]
MEM_DIR = ROOT / "memory"
INDEX = MEM_DIR / "MEMORY.md"


def parse_frontmatter(text: str) -> dict | None:
    m = FRONTMATTER_RE.match(text)
    if not m:
        return None
    fm: dict[str, str] = {}
    for line in m.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip()
    return fm


def main() -> int:
    if not MEM_DIR.exists():
        print(f"no memory/ dir at {MEM_DIR}", file=sys.stderr)
        return 0

    errors: list[str] = []
    mem_files = sorted(p for p in MEM_DIR.glob("*.md") if p.name != "MEMORY.md")

    for f in mem_files:
        text = f.read_text(encoding="utf-8")
        fm = parse_frontmatter(text)
        if fm is None:
            errors.append(f"{f.name}: missing frontmatter")
            continue
        for key in ("name", "description", "type"):
            if key not in fm:
                errors.append(f"{f.name}: missing frontmatter key '{key}'")
        t = fm.get("type", "")
        if t and t not in VALID_TYPES:
            errors.append(f"{f.name}: type '{t}' not in {sorted(VALID_TYPES)}")
        prefix = t + "_" if t in VALID_TYPES else None
        if prefix and not f.name.startswith(prefix):
            errors.append(f"{f.name}: filename should start with '{prefix}' for type={t}")

    # Index integrity: every non-index file must be linked from MEMORY.md
    if INDEX.exists():
        idx_text = INDEX.read_text(encoding="utf-8")
        line_count = idx_text.count("\n")
        if line_count > 200:
            errors.append(f"MEMORY.md: {line_count} lines exceeds 200-line cap")
        linked = {Path(m).name for m in INDEX_LINK_RE.findall(idx_text)}
        for f in mem_files:
            if f.name not in linked:
                errors.append(f"MEMORY.md: missing index entry for {f.name}")
    else:
        errors.append("MEMORY.md not found")

    for e in errors:
        print(f"error: {e}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
