#!/usr/bin/env bash
# Gemini CLI 어댑터 — .harness/commands, .harness/agents를 .gemini/로 노출.
#
# Gemini CLI는 루트 `GEMINI.md`를 자동 로드하지만, 네이티브 슬래시 커맨드 형식은 TOML이다.
# v1 어댑터는 마크다운 파일만 심볼릭 링크하고 프롬프트 기반 호출 워크플로를 쓴다
# (Codex와 동일). TOML 생성은 v2 범위.
set -euo pipefail

COPY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy) COPY=1; shift ;;
    -h|--help) echo "Usage: compile.sh [--copy]"; exit 0 ;;
    *) echo "unknown: $1" >&2; exit 2 ;;
  esac
done

ROOT="$(pwd)"
HARNESS_CMDS="$ROOT/.harness/commands"
HARNESS_AGENTS="$ROOT/.harness/agents"
GEMINI_CMDS="$ROOT/.gemini/commands"
GEMINI_AGENTS="$ROOT/.gemini/agents"

mkdir -p "$GEMINI_CMDS" "$GEMINI_AGENTS"

link_or_copy() {
  local src="$1" dst="$2"
  [[ -e "$dst" || -L "$dst" ]] && rm -f "$dst"
  if [[ "$COPY" == 1 ]]; then
    cp "$src" "$dst"
  else
    ln -s "$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$src" "$(dirname "$dst")")" "$dst"
  fi
}

echo "[adapter:gemini] 커맨드 연결: .harness/commands → .gemini/commands"
for f in "$HARNESS_CMDS"/*.md; do
  [[ -f "$f" ]] || continue
  name="$(basename "$f")"
  link_or_copy "$f" "$GEMINI_CMDS/$name"
  echo "  ${name%.md}"
done

echo "[adapter:gemini] 에이전트 연결: .harness/agents → .gemini/agents"
for f in "$HARNESS_AGENTS"/*.md; do
  [[ -f "$f" ]] || continue
  name="$(basename "$f")"
  link_or_copy "$f" "$GEMINI_AGENTS/$name"
  echo "  ${name%.md}"
done

# 네이티브 TOML 불일치 안내 README — 기존 파일 있으면 보존
README="$ROOT/.gemini/README.harness.md"
if [[ ! -f "$README" ]]; then
  cat > "$README" <<'EOF'
# Harness × Gemini CLI

이 디렉터리는 하네스가 Gemini CLI용으로 컴파일한 결과입니다.

## 중요: 네이티브 슬래시 커맨드는 아직 미지원

Gemini CLI의 네이티브 커스텀 커맨드는 TOML 형식인 반면 하네스는 마크다운 기반입니다.
v1 어댑터는 파일을 심볼릭 링크만 합니다. 슬래시 커맨드로 직접 호출되지 않습니다.

## 사용 방법 (프롬프트 기반)

Gemini CLI에 다음과 같이 입력하세요:

> `.gemini/commands/new-track.md` 파일을 읽고 인자 `"사용자 로그인"`으로 지시대로 실행해줘.

`GEMINI.md`(루트)가 에이전트 목차와 워크플로 규칙을 이미 로드합니다.

## 참고

- 에이전트: `.gemini/agents/*.md`
- 커맨드: `.gemini/commands/*.md`
- 원본: `.harness/commands/`, `.harness/agents/`
EOF
  echo "[adapter:gemini] .gemini/README.harness.md 생성 (TOML 불일치 안내)"
fi

echo "[adapter:gemini] 완료. GEMINI.md 자동 로드 + 프롬프트 기반 커맨드 호출."
