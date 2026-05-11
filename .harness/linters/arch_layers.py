#!/usr/bin/env python3
"""Enforce layer-order: imports flow downward only.

Layer order is defined in .harness/config.yaml guardrails.layer_order.
A file in layer L may import from layers at index >= L's index (i.e. below or same).
Module's layer is inferred from path: the first layer name that appears as a
directory component.

Plugin system: language-specific import parsers live under
.harness/linters/plugins/ and implement `detect_imports(path: Path) -> list[str]`.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / ".harness" / "config.yaml"

DEFAULT_LAYERS = ["types", "config", "repo", "service", "runtime", "ui"]


def load_layers() -> list[str]:
    if not CONFIG.exists():
        return DEFAULT_LAYERS
    layers: list[str] = []
    in_order = False
    for line in CONFIG.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("layer_order:"):
            in_order = True
            continue
        if in_order:
            m = re.match(r"\s+-\s+(\w+)", line)
            if m:
                layers.append(m.group(1))
            elif line.strip() and not line.startswith(" "):
                break
    return layers or DEFAULT_LAYERS


def file_layer(path: Path, layers: list[str]) -> str | None:
    parts = [p.lower() for p in path.parts]
    for layer in layers:
        if layer in parts:
            return layer
    return None


IMPORT_RE_PY = re.compile(r"^\s*(?:from\s+([\w.]+)|import\s+([\w.]+))", re.MULTILINE)
IMPORT_RE_TS = re.compile(r"""(?:^|\n)\s*(?:import\s+(?:.+?\s+from\s+)?['"]([^'"]+)['"]|(?:const|let|var)\s+.+?=\s*require\(['"]([^'"]+)['"]\))""", re.DOTALL)


def parse_imports(p: Path) -> list[str]:
    text = p.read_text(encoding="utf-8", errors="replace")
    if p.suffix == ".py":
        return [g1 or g2 for g1, g2 in IMPORT_RE_PY.findall(text)]
    if p.suffix in (".ts", ".tsx", ".js", ".jsx", ".mjs"):
        return [a or b for a, b in IMPORT_RE_TS.findall(text)]
    return []


def imported_layer(spec: str, layers: list[str]) -> str | None:
    tokens = re.split(r"[./]", spec)
    for layer in layers:
        if layer in tokens:
            return layer
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="exit 0 regardless")
    ap.add_argument("paths", nargs="*", type=Path)
    args = ap.parse_args()

    layers = load_layers()
    layer_idx = {name: i for i, name in enumerate(layers)}

    roots = args.paths or [ROOT]
    violations: list[str] = []
    scanned = 0

    for root in roots:
        if root.is_file():
            files = [root]
        else:
            files = [p for p in root.rglob("*")
                     if p.is_file()
                     and p.suffix in {".py", ".ts", ".tsx", ".js", ".jsx", ".mjs"}
                     and ".harness" not in p.parts
                     and "node_modules" not in p.parts
                     and "__pycache__" not in p.parts]

        for f in files:
            scanned += 1
            src_layer = file_layer(f, layers)
            if src_layer is None:
                continue
            src_i = layer_idx[src_layer]
            for imp in parse_imports(f):
                tgt_layer = imported_layer(imp, layers)
                if tgt_layer is None:
                    continue
                tgt_i = layer_idx[tgt_layer]
                # Downward-only: src may import layers at same or lower index
                if tgt_i > src_i:
                    try:
                        shown = f.relative_to(ROOT)
                    except ValueError:
                        shown = f
                    violations.append(
                        f"{shown}: layer '{src_layer}' imports "
                        f"from higher layer '{tgt_layer}' (via '{imp}').\n"
                        f"  fix: move the import target down, or invert the "
                        f"dependency via an interface in layer 'types'."
                    )

    for v in violations:
        print(f"error: {v}", file=sys.stderr)

    if args.dry_run:
        print(f"scanned {scanned} files, {len(violations)} violations (dry-run)")
        return 0
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main())
