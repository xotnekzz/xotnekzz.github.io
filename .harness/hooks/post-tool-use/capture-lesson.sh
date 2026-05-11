#!/usr/bin/env bash
# post-tool-use 훅 — 에이전트의 자기-교정 발언을 감지해 memory/feedback_*.md 드래프트 제안.
#
# "죄송", "다시 시도", "이전 접근", "실수" 같은 패턴이 최근 어시스턴트 출력에 있으면
# memory/.drafts/에 타임스탬프된 후보 파일 기록.
#
# 게이트(A-3):
#   - tool이 Edit/Write/Bash일 때만 스캔 (Read/Grep/Glob은 자기-교정 신호 아님)
#   - assistant_text 앞 500자만 스캔 (tool output의 노이즈 제외)
#   - 최근 5분 내 드래프트 존재 시 debounce
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/.harness/hooks/_lib.sh"
harness_hook_start "post-tool-use/capture-lesson"

PAYLOAD="${1:-$(cat 2>/dev/null || echo '')}"
[[ -z "$PAYLOAD" ]] && exit 0

# 게이트 1: 툴 필터. 편집/실행 계열만.
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

# 게이트 2: debounce — 최근 5분 내 드래프트가 있으면 스킵.
DRAFTS_DIR="$ROOT/memory/.drafts"
if [[ -d "$DRAFTS_DIR" ]]; then
  LATEST=$(ls -t "$DRAFTS_DIR"/feedback_*.md 2>/dev/null | head -1 || true)
  if [[ -n "$LATEST" ]]; then
    # macOS는 stat -f, Linux는 stat -c. 실패 시 debounce 건너뜀.
    MTIME=$(stat -f %m "$LATEST" 2>/dev/null || stat -c %Y "$LATEST" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    AGE=$(( NOW - MTIME ))
    if [[ $MTIME -gt 0 && $AGE -lt 300 ]]; then
      exit 0
    fi
  fi
fi

# 게이트 3: assistant_text 앞 500자만. tool output은 무시(노이즈).
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
  TS=$(date -u +%Y%m%dT%H%M%SZ)
  DRAFT="$DRAFTS_DIR/feedback_${TS}.md"
  mkdir -p "$DRAFTS_DIR"
  cat > "$DRAFT" <<EOF
---
name: 자동 드래프트 피드백 ${TS}
description: capture-lesson 훅이 자기-교정 신호로 감지 — 사용자 검토 필요
type: feedback
status: draft
---

## 컨텍스트 스니펫

$TEXT

**Why:** _(사용자 기입)_

**How to apply:** _(사용자 기입)_
EOF
  echo "capture-lesson: 드래프트 생성됨 $DRAFT (검토 후 memory/에 반영)" >&2
fi
exit 0
