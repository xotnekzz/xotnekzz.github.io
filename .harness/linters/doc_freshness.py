#!/usr/bin/env python3
"""Flag drift between docs/ and code.

Heuristic:
- Collect identifiers referenced in docs via `backtick-quoted` code spans
  matching Python/TS identifier shape.
- Collect identifiers defined in code (class/def/function/const exports).
- Report doc identifiers not found in code (possibly renamed/removed).

This is a soft signal — warnings only.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs"

DOC_IDENT_RE = re.compile(r"`([A-Za-z_][A-Za-z0-9_]{2,})`")
CODE_DEF_RE = re.compile(
    r"(?:^|\n)\s*(?:class|def|function|const|let|var|export\s+(?:class|function|const))\s+([A-Za-z_][A-Za-z0-9_]+)"
)

SKIP_WORDS = {"True", "False", "None", "null", "undefined", "TODO", "FIXME"}


def collect_code_symbols() -> set[str]:
    syms: set[str] = set()
    for f in ROOT.rglob("*"):
        if not f.is_file():
            continue
        if f.suffix not in {".py", ".ts", ".tsx", ".js", ".jsx"}:
            continue
        if any(part in f.parts for part in (".harness", "node_modules", "__pycache__", ".git")):
            continue
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        syms.update(CODE_DEF_RE.findall(text))
    return syms


def main() -> int:
    if not DOCS.exists():
        return 0
    code_syms = collect_code_symbols()
    warnings: list[str] = []

    for doc in DOCS.rglob("*.md"):
        text = doc.read_text(encoding="utf-8")
        doc_syms = set(DOC_IDENT_RE.findall(text)) - SKIP_WORDS
        for sym in sorted(doc_syms):
            # identifier-shaped, likely a code symbol, but not found
            if sym not in code_syms and re.match(r"^[A-Z][a-zA-Z0-9]*$|^[a-z_][a-z0-9_]+$", sym):
                if sym.islower() and len(sym) < 5:
                    continue  # skip short common words
                warnings.append(f"{doc.relative_to(ROOT)}: `{sym}` referenced in doc but not found in code")

    for w in warnings[:50]:  # cap noise
        print(f"warn: {w}", file=sys.stderr)
    if len(warnings) > 50:
        print(f"warn: ... {len(warnings) - 50} more", file=sys.stderr)
    return 0  # warnings only


if __name__ == "__main__":
    sys.exit(main())
