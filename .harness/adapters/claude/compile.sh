#!/usr/bin/env bash
# Claude Code 어댑터 — .harness/commands와 .harness/agents를 Claude Code가 읽는
# .claude/commands, .claude/agents로 노출한다.
#
# Claude Code의 슬래시 커맨드는 `.claude/commands/<name>.md`의 파일명에서 온다.
# 에이전트는 `.claude/agents/<name>.md` (프런트매터 필요).
#
# 전략: 심볼릭 링크. 심볼릭 링크가 안 먹는 FS(일부 Windows)면 --copy 플래그.
set -euo pipefail

COPY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy) COPY=1; shift ;;
    -h|--help)
      echo "Usage: compile.sh [--copy]"; exit 0 ;;
    *) echo "unknown: $1" >&2; exit 2 ;;
  esac
done

ROOT="$(pwd)"
HARNESS_CMDS="$ROOT/.harness/commands"
HARNESS_AGENTS="$ROOT/.harness/agents"
CLAUDE_CMDS="$ROOT/.claude/commands"
CLAUDE_AGENTS="$ROOT/.claude/agents"

mkdir -p "$CLAUDE_CMDS" "$CLAUDE_AGENTS"

link_or_copy() {
  local src="$1" dst="$2"
  # 기존 링크/파일 제거
  [[ -e "$dst" || -L "$dst" ]] && rm -f "$dst"
  if [[ "$COPY" == 1 ]]; then
    cp "$src" "$dst"
  else
    # dst 기준 상대 경로 심볼릭 링크 (이식성)
    ln -s "$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$src" "$(dirname "$dst")")" "$dst"
  fi
}

echo "[adapter:claude] 커맨드 연결: .harness/commands → .claude/commands"
for f in "$HARNESS_CMDS"/*.md; do
  [[ -f "$f" ]] || continue
  name="$(basename "$f")"
  link_or_copy "$f" "$CLAUDE_CMDS/$name"
  echo "  /${name%.md}"
done

echo "[adapter:claude] 에이전트 연결: .harness/agents → .claude/agents"
for f in "$HARNESS_AGENTS"/*.md; do
  [[ -f "$f" ]] || continue
  name="$(basename "$f")"
  link_or_copy "$f" "$CLAUDE_AGENTS/$name"
  echo "  $(basename "${name%.md}")"
done

# settings.json에 훅 등록 제안 (덮어쓰지 않음)
SETTINGS="$ROOT/.claude/settings.json"
if [[ ! -f "$SETTINGS" ]]; then
  cat > "$SETTINGS" <<'JSON'
{
  "hooks": {
    "pre-tool-use":       [{"command": ".harness/hooks/pre-tool-use/enforce-arch.sh"}],
    "post-tool-use":      [{"command": ".harness/hooks/post-tool-use/capture-lesson.sh"}],
    "user-prompt-submit": [{"command": ".harness/hooks/user-prompt-submit/inject-moc.sh"}],
    "stop":               [{"command": ".harness/hooks/stop/handoff.sh"}]
  }
}
JSON
  echo "[adapter:claude] .claude/settings.json 생성 (훅 4개 등록됨)"
else
  echo "[adapter:claude] .claude/settings.json 존재 — 덮어쓰지 않음 (훅 수동 등록 필요 시 .harness/adapters/claude/settings.example.json 참고)"
fi

echo "[adapter:claude] 완료. Claude Code를 재시작하거나 새 세션에서 확인하세요."
