#!/usr/bin/env bash
# post-tool-use 훅 — 에이전트의 자기-교정 발언을 감지해 활성 트랙 Log에 기록.
#
# 게이트(A-3):
#   - tool이 Edit/Write/Bash일 때만 스캔
#   - assistant_text 앞 500자만 스캔
#   - 최근 5분 내 기록 존재 시 debounce
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/.harness/hooks/_lib.sh"
harness_hook_start "post-tool-use/capture-lesson"

PAYLOAD="${1:-$(cat 2>/dev/null || echo '')}"
[[ -z "$PAYLOAD" ]] && exit 0

TOOL=$(python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    print(d.get('tool', '') or d.get('tool_name', ''), end='')
except Exception:
    pass
" "$PAYLOAD" 2>/dev/null || echo '')

case "$TOOL" in
  Edit|Write|Bash|MultiEdit) ;;
  *) exit 0 ;;
esac

TEXT=$(python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    t = d.get('assistant_text', '') or ''
    print(t[:500])
except Exception:
    print('')
" "$PAYLOAD" 2>/dev/null || echo '')

[[ -z "$TEXT" ]] && exit 0

if echo "$TEXT" | grep -qiE '(죄송|다시\s*(시도|해|생각)|이전\s*접근|sorry|let me try again|my mistake|revert)'; then
  # 활성 트랙이 있으면 해당 트랙 Log에 append
  TRACKS_DIR="$ROOT/.harness/tracks"
  ACTIVE_TRACK=$(ls "$TRACKS_DIR"/*.md 2>/dev/null | grep -v '_template' | head -1 || true)
  if [[ -n "$ACTIVE_TRACK" ]]; then
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "$TS [auto] 자기-교정 감지 — 검토 필요" >> "$ACTIVE_TRACK"
    echo "capture-lesson: $ACTIVE_TRACK Log에 기록" >&2
  fi
fi
exit 0
