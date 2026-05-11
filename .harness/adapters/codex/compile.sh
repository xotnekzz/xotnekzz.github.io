#!/usr/bin/env bash
# Codex CLI 어댑터 — .harness/commands, .harness/agents를 .codex/로 노출.
#
# Codex CLI는 슬래시 커맨드/훅 시스템이 없다. 대신 루트 `AGENTS.md`를 자동 로드하므로
# 커맨드/에이전트 파일은 프롬프트에서 참조 ("X.md 파일을 읽고 지시대로 실행")로 호출한다.
# 훅 fallback이 필요하면 .harness/daemon/watcher.py를 백그라운드 실행.
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
CODEX_CMDS="$ROOT/.codex/commands"
CODEX_AGENTS="$ROOT/.codex/agents"

mkdir -p "$CODEX_CMDS" "$CODEX_AGENTS"

link_or_copy() {
  local src="$1" dst="$2"
  [[ -e "$dst" || -L "$dst" ]] && rm -f "$dst"
  if [[ "$COPY" == 1 ]]; then
    cp "$src" "$dst"
  else
    ln -s "$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$src" "$(dirname "$dst")")" "$dst"
  fi
}

echo "[adapter:codex] 커맨드 연결: .harness/commands → .codex/commands"
for f in "$HARNESS_CMDS"/*.md; do
  [[ -f "$f" ]] || continue
  name="$(basename "$f")"
  link_or_copy "$f" "$CODEX_CMDS/$name"
  echo "  ${name%.md}"
done

echo "[adapter:codex] 에이전트 연결: .harness/agents → .codex/agents"
for f in "$HARNESS_AGENTS"/*.md; do
  [[ -f "$f" ]] || continue
  name="$(basename "$f")"
  link_or_copy "$f" "$CODEX_AGENTS/$name"
  echo "  ${name%.md}"
done

echo "[adapter:codex] 완료. Codex는 슬래시 커맨드 대신 다음 프롬프트로 호출:"
echo "  \".codex/commands/<name>.md 파일을 읽고 지시대로 실행해줘\""
echo "[adapter:codex] (선택) 훅 fallback: python3 .harness/daemon/watcher.py --interval 60 &"
