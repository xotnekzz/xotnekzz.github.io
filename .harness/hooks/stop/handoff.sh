#!/usr/bin/env bash
# stop 훅 — 세션 종료 시 활성 트랙이 있으면 handoff 힌트를 트랙 Log에 기록.
#
# 게이트(A-4): tracks/*.md 없으면 즉시 exit
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/.harness/hooks/_lib.sh"
harness_hook_start "stop/handoff"

TRACKS_DIR="$ROOT/.harness/tracks"
[[ -d "$TRACKS_DIR" ]] || exit 0

shopt -s nullglob
FILES=("$TRACKS_DIR"/*.md)
# _template.md 제외
ACTIVE=()
for f in "${FILES[@]}"; do
  [[ "$(basename "$f")" == "_template.md" ]] && continue
  ACTIVE+=("$f")
done
[[ ${#ACTIVE[@]} -eq 0 ]] && exit 0

for TRACK_FILE in "${ACTIVE[@]}"; do
  TRACK=$(basename "$TRACK_FILE" .md)

  # 미체크 박스 존재?
  if grep -q '^\- \[ \]' "$TRACK_FILE"; then
    NEXT=$(grep -m1 '^\- \[ \]' "$TRACK_FILE" | sed 's/^- \[ \] //')
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    # Log 섹션이 있으면 append, 없으면 파일 끝에 추가
    if grep -q '^## Log' "$TRACK_FILE"; then
      sed -i.bak "/^## Log/a $TS [handoff] 세션 종료. 다음: $NEXT" "$TRACK_FILE" && rm -f "${TRACK_FILE}.bak"
    else
      echo "" >> "$TRACK_FILE"
      echo "## Log" >> "$TRACK_FILE"
      echo "$TS [handoff] 세션 종료. 다음: $NEXT" >> "$TRACK_FILE"
    fi
    echo "stop: $TRACK 핸드오프 Log 기록" >&2
  fi
done
exit 0
