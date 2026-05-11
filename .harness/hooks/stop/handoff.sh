#!/usr/bin/env bash
# stop 훅 — 세션 종료 시 활성 트랙이 있으면 handoff.md 작성.
# context-reset 스킬의 최소 자동 버전.
#
# 게이트(A-4):
#   - active/ 비었으면 즉시 exit (nullglob)
#   - plan.md가 기존 handoff.md보다 최신일 때만 재작성
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/.harness/hooks/_lib.sh"
harness_hook_start "stop/handoff"

ACTIVE="$ROOT/.harness/tracks/active"
[[ -d "$ACTIVE" ]] || exit 0

shopt -s nullglob
DIRS=("$ACTIVE"/*/)
[[ ${#DIRS[@]} -eq 0 ]] && exit 0

for d in "${DIRS[@]}"; do
  TRACK=$(basename "$d")
  PLAN="$d/plan.md"
  HANDOFF="$d/handoff.md"
  [[ -f "$PLAN" ]] || continue

  # handoff가 plan보다 최신이면 재작성 불필요 (이 세션에서 plan을 안 건드렸다는 신호).
  if [[ -f "$HANDOFF" && "$HANDOFF" -nt "$PLAN" ]]; then
    continue
  fi

  # 미체크 박스 존재?
  if grep -q '^\- \[ \]' "$PLAN"; then
    NEXT=$(grep -m1 '^\- \[ \]' "$PLAN" | sed 's/^- \[ \] //')
    cat > "$HANDOFF" <<EOF
---
track: $TRACK
generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
from_model: auto-generated-by-stop-hook
---

## 상태
- plan.md 미완료 항목 존재

## 다음 액션
- $NEXT

## 컨텍스트 힌트
- 먼저 읽을 파일: plan.md, sprint-contract.md, progress.md
EOF
    echo "stop: $TRACK 핸드오프 작성 → $HANDOFF" >&2
  fi
done
exit 0
