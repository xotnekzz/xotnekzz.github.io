#!/usr/bin/env bash
# pre-tool-use 훅 — 파일 편집 전 아키텍처 레이어 위반 차단.
# Claude Code 같은 CLI가 Edit/Write 툴 호출 직전 실행.
#
# 입력: stdin JSON — { "tool": "...", "input": { "file_path": "..." } }
# 출력: exit 0 = 허용, exit != 0 = 차단 (이유는 stderr)
#
# 게이트(A-2): 코드 확장자 + 코드 루트 하위일 때만 린터 스폰.
# 문서/설정/메모리/하네스 내부 편집은 즉시 통과.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/.harness/hooks/_lib.sh"
harness_hook_start "pre-tool-use/enforce-arch"

# CLI가 JSON을 주지 않으면 통과(스킵).
if ! command -v python3 >/dev/null 2>&1; then
  exit 0
fi

PAYLOAD="${1:-$(cat 2>/dev/null || echo '')}"
if [[ -z "$PAYLOAD" ]]; then
  exit 0
fi

FILE=$(python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    print((d.get('input') or {}).get('file_path') or '', end='')
except Exception:
    pass
" "$PAYLOAD" 2>/dev/null || true)

[[ -z "$FILE" ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

# 게이트 1: 확장자 화이트리스트. 코드 파일만 arch 검사 대상.
case "$FILE" in
  *.py|*.ts|*.tsx|*.js|*.jsx|*.mjs|*.go|*.rs|*.java|*.kt|*.swift) ;;
  *) exit 0 ;;
esac

# 게이트 2: 경로 제외. 하네스 내부/의존성/테스트 아티팩트는 레이어 규칙 대상 아님.
case "$FILE" in
  */.harness/*|*/node_modules/*|*/__pycache__/*|*/.venv/*|*/dist/*|*/build/*) exit 0 ;;
esac

# 게이트 3: 코드 루트 화이트리스트. 프로젝트별로 config.yaml의 guardrails.arch_layers.include_paths로 확장 가능.
# 기본: src/ app/ lib/ packages/ 하위만. 그 외(docs, scripts, examples 등)는 통과.
INCLUDE_RE='/(src|app|lib|packages)/'
if ! [[ "$FILE" =~ $INCLUDE_RE ]]; then
  exit 0
fi

# 단일 파일에 대해 아키텍처 린터 실행
if ! python3 "$ROOT/.harness/linters/arch_layers.py" "$FILE" 2>&1; then
  echo "pre-tool-use: 아키텍처 레이어 위반 — 편집 차단" >&2
  echo "수정 후 재시도하거나 $ROOT/ARCHITECTURE.md 참조" >&2
  exit 2
fi
exit 0
