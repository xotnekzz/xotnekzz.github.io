#!/usr/bin/env bash
# 훅 공용 유틸: 타이밍 계측 + 게이트 헬퍼.
# 각 훅에서 `source "$(dirname ...)/../_lib.sh"` 후 `harness_hook_start "<name>"` 호출.

harness_hook_start() {
  local name="$1"
  HARNESS_HOOK_NAME="$name"
  HARNESS_HOOK_START_NS=$(date +%s%N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1e9))')
  # trap에서 참조할 ROOT 보장 (호출자가 설정했으면 유지)
  HARNESS_HOOK_ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[1]}")/../.." && pwd)}"
  trap 'harness_hook_end' EXIT
}

harness_hook_end() {
  local rc=$?
  local end_ns now_ns dur_ms
  now_ns=$(date +%s%N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1e9))')
  dur_ms=$(( (now_ns - HARNESS_HOOK_START_NS) / 1000000 ))
  local log="$HARNESS_HOOK_ROOT/.harness/.timing.log"
  # 로그는 베스트-에포트. 실패해도 훅 결과에 영향 없음.
  printf '%s\t%s\t%dms\trc=%d\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$HARNESS_HOOK_NAME" \
    "$dur_ms" \
    "$rc" >> "$log" 2>/dev/null || true
  return $rc
}
