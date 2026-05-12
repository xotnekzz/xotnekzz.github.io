#!/usr/bin/env bash
# user-prompt-submit 훅 — 사용자 프롬프트 키워드에 매칭되는 파일만 컨텍스트에 주입.
# 과부하 방지: 전체 .harness/docs/ 덤프 금지.
#
# 게이트(A-1): 짧은 프롬프트·슬래시 커맨드는 즉시 통과.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/.harness/hooks/_lib.sh"
harness_hook_start "user-prompt-submit/inject-moc"

PAYLOAD="${1:-$(cat 2>/dev/null || echo '')}"
[[ -z "$PAYLOAD" ]] && exit 0

if [[ ${#PAYLOAD} -lt 80 ]]; then
  exit 0
fi

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

[[ ${#PROMPT} -lt 40 ]] && exit 0

declare -a INJECT=()
shopt -s nocasematch
[[ "$PROMPT" =~ (플랜|plan|구현|implement|track|트랙|기능|feature) ]] && INJECT+=(".harness/Track.md")
[[ "$PROMPT" =~ (아키|architecture|레이어|layer|import) ]] && INJECT+=(".harness/ARCHITECTURE.md")
[[ "$PROMPT" =~ (보안|security|auth|암호) ]] && INJECT+=(".harness/docs/SECURITY.md")
[[ "$PROMPT" =~ (로그|log|신뢰|reliab) ]] && INJECT+=(".harness/docs/RELIABILITY.md")
[[ "$PROMPT" =~ (설계|design|decision|컨벤션) ]] && INJECT+=(".harness/docs/DESIGN.md")
shopt -u nocasematch

if [[ ${#INJECT[@]} -gt 0 ]]; then
  {
    echo "<harness-context>"
    echo "관련 컨텍스트 (필요할 때만 읽으시오 — 점진 공개 원칙):"
    for m in "${INJECT[@]}"; do
      echo "- $m"
    done
    echo "</harness-context>"
  } >&2
fi
exit 0
