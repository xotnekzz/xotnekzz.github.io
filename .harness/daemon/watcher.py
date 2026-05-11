#!/usr/bin/env python3
"""훅 미지원 CLI를 위한 파일 워처 fallback.

`.harness/tracks/active/**`, 커밋 이벤트를 폴링해 stop/handoff 로직과 유사한
동작을 수행한다. Claude Code의 네이티브 훅이 있으면 이 데몬은 불필요.

사용: python3 .harness/daemon/watcher.py --interval 60
"""
from __future__ import annotations

import argparse
import hashlib
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACTIVE = ROOT / ".harness" / "tracks" / "active"
STATE = ROOT / ".harness" / ".watcher-state"


def snapshot() -> dict[str, str]:
    out: dict[str, str] = {}
    if not ACTIVE.exists():
        return out
    for f in ACTIVE.rglob("plan.md"):
        h = hashlib.sha256(f.read_bytes()).hexdigest()
        out[str(f.relative_to(ROOT))] = h
    return out


def load_state() -> dict[str, str]:
    if not STATE.exists():
        return {}
    return dict(
        line.strip().split("  ", 1)[::-1]
        for line in STATE.read_text().splitlines()
        if "  " in line
    )


def save_state(snap: dict[str, str]) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text("\n".join(f"{h}  {p}" for p, h in sorted(snap.items())))


def on_change(path: str) -> None:
    print(f"[watcher] plan changed: {path}", file=sys.stderr)
    script = ROOT / ".harness" / "hooks" / "stop" / "handoff.sh"
    if script.exists():
        subprocess.run(["bash", str(script)], check=False)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--interval", type=int, default=60)
    ap.add_argument("--once", action="store_true")
    args = ap.parse_args()

    prev = load_state()
    while True:
        cur = snapshot()
        for p, h in cur.items():
            if prev.get(p) != h:
                on_change(p)
        save_state(cur)
        prev = cur
        if args.once:
            return 0
        time.sleep(args.interval)


if __name__ == "__main__":
    sys.exit(main())
