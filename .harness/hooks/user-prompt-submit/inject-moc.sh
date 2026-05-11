#!/usr/bin/env bash
# user-prompt-submit 훅 — 사용자 프롬프트 키워드에 매칭되는 MOC만 컨텍스트에 주입.
# 과부하 방지: 전체 docs/ 덤프 금지.
#
# 게이트(A-1): 짧은 프롬프트·슬래시 커맨드는 파이썬 스폰 없이 즉시 통과.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/.harness/hooks/_lib.sh"
harness_hook_start "user-prompt-submit/inject-moc"

PAYLOAD="${1:-$(cat 2>/dev/null || echo '')}"
[[ -z "$PAYLOAD" ]] && exit 0

# 빠른 게이트 1: JSON 포함 오버헤드 감안 80B 미만은 실질 프롬프트가 너무 짧음.
if [[ ${#PAYLOAD} -lt 80 ]]; then
  exit 0
fi

# 빠른 게이트 2: 슬래시 커맨드는 커맨드 정의 자체가 컨텍스트를 가지므로 주입 불필요.
# JSON 안에서 "prompt":"/..." 패턴 탐지.
if [[ "$PAYLOAD" == *'"prompt":"/'* ]] || [[ "$PAYLOAD" == *'"prompt": "/'* ]]; then
  exit 0
fi

PROMPT=$(python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    print(d.get('prompt', ''), end='')
except Exception:
    pass
" "$PAYLOAD" 2>/dev/null || echo '')

# 게이트 3: 파싱 후 실제 프롬프트 길이가 40자 미만이면 잡담/간단 질문 확률↑
[[ ${#PROMPT} -lt 40 ]] && exit 0

# 키워드 → 관련 MOC 매핑
declare -a INJECT=()
shopt -s nocasematch
[[ "$PROMPT" =~ (스펙|spec|요구|기능|feature) ]] && INJECT+=("docs/product-specs/index.md")
[[ "$PROMPT" =~ (플랜|plan|구현|implement|track|트랙) ]] && INJECT+=(".harness/tracks/active/")
[[ "$PROMPT" =~ (아키|architecture|레이어|layer|import) ]] && INJECT+=("ARCHITECTURE.md")
[[ "$PROMPT" =~ (보안|security|auth|암호) ]] && INJECT+=("docs/SECURITY.md")
[[ "$PROMPT" =~ (로그|log|신뢰|reliab) ]] && INJECT+=("docs/RELIABILITY.md")
[[ "$PROMPT" =~ (설계|design|decision) ]] && INJECT+=("docs/design-docs/index.md")
[[ "$PROMPT" =~ (메모리|memory|기억) ]] && INJECT+=("memory/MEMORY.md")
shopt -u nocasematch

if [[ ${#INJECT[@]} -gt 0 ]]; then
  {
    echo "<harness-moc-injection>"
    echo "사용자 프롬프트와 관련된 컨텍스트 맵:"
    for m in "${INJECT[@]}"; do
      echo "- $m"
    done
    echo "필요할 때만 읽으시오 (점진 공개 원칙)."
    echo "</harness-moc-injection>"
  } >&2
fi
exit 0
