#!/usr/bin/env bash
# harness migrate — v1(multi-file) → v2(single-file track) 마이그레이션.
# 멱등성: 이미 v2면 "nothing to do" 출력.
set -euo pipefail

DRY_RUN=0
ASSUME_YES=0
SRC_DIR=""

usage() {
  cat <<EOF
Usage: migrate.sh [options]

  --dry-run      변경 없이 프리뷰
  --yes, -y      확인 프롬프트 건너뜀
  --source <path> 하네스 스켈레톤 루트 (자동 감지)
  -h, --help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y)  ASSUME_YES=1; shift ;;
    --source)  SRC_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown flag: $1" >&2; usage; exit 2 ;;
  esac
done

DEST_DIR="$(pwd)"

if [[ -z "$SRC_DIR" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SRC_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

log()  { printf '[migrate] %s\n' "$*"; }
info() { printf '[migrate] \033[33m%s\033[0m\n' "$*"; }
ok()   { printf '[migrate] \033[32m✓ %s\033[0m\n' "$*"; }
warn() { printf '[migrate] \033[31m⚠ %s\033[0m\n' "$*"; }

# ─── v1 구조 감지 ─────────────────────────────────────────────────────────────

HAS_OLD=0
OLD_ITEMS=()

[[ -f "$DEST_DIR/HARNESS_MAP.md" ]]                    && { OLD_ITEMS+=("HARNESS_MAP.md"); HAS_OLD=1; }
[[ -d "$DEST_DIR/.harness/commands" ]]                 && { OLD_ITEMS+=(".harness/commands/"); HAS_OLD=1; }
[[ -f "$DEST_DIR/.harness/linters/memory_schema.py" ]] && { OLD_ITEMS+=(".harness/linters/memory_schema.py"); HAS_OLD=1; }
[[ -d "$DEST_DIR/.harness/tracks/active" ]]            && { OLD_ITEMS+=(".harness/tracks/active/"); HAS_OLD=1; }
[[ -d "$DEST_DIR/memory" ]]                            && { OLD_ITEMS+=("memory/"); HAS_OLD=1; }
[[ -f "$DEST_DIR/ARCHITECTURE.md" ]]                   && { OLD_ITEMS+=("ARCHITECTURE.md (루트)"); HAS_OLD=1; }
# docs/ 루트 — 하네스 파일만 있는지 확인
HARNESS_DOC_NAMES=("USAGE.md" "DESIGN.md" "RELIABILITY.md" "SECURITY.md" "QUALITY_SCORE.md" "CLI_COMPAT.md" "CONTRIBUTING.md")
if [[ -d "$DEST_DIR/docs" ]]; then
  OLD_ITEMS+=("docs/ (루트)"); HAS_OLD=1
fi

if [[ "$HAS_OLD" == 0 ]]; then
  log "v2 구조 감지 — nothing to do."
  exit 0
fi

echo
log "마이그레이션 대상:"
for item in "${OLD_ITEMS[@]}"; do
  printf '  - %s\n' "$item"
done
echo

if [[ "$ASSUME_YES" != 1 && "$DRY_RUN" != 1 ]]; then
  read -r -p "[migrate] 계속 진행할까요? [Y/n] " ans
  case "${ans:-Y}" in y|Y|yes|YES|"") ;; *) echo "[migrate] 취소됨"; exit 130 ;; esac
fi

do_run() { [[ "$DRY_RUN" == 0 ]]; }

# ─── Step 1: 새 스켈레톤 동기화 ─────────────────────────────────────────────

log "1/6 새 스켈레톤 파일 동기화..."
if do_run; then
  bash "$SRC_DIR/.harness/templates/init.sh" --source "$SRC_DIR" --yes 2>/dev/null || true
  ok "스켈레톤 동기화 완료"
else
  log "DRY: init.sh --yes 실행"
fi

# ─── Step 2: 트랙 파일 마이그레이션 ─────────────────────────────────────────

log "2/6 트랙 파일 통합 (multi-file → single .md)..."

ACTIVE_DIR="$DEST_DIR/.harness/tracks/active"
TRACKS_DIR="$DEST_DIR/.harness/tracks"
TRACK_INDEX="$DEST_DIR/.harness/Track.md"

if [[ -d "$ACTIVE_DIR" ]]; then
  shopt -s nullglob
  TRACK_DIRS=("$ACTIVE_DIR"/*/)
  shopt -u nullglob

  for d in "${TRACK_DIRS[@]}"; do
    TRACK=$(basename "$d")
    OUT="$TRACKS_DIR/${TRACK}.md"

    if do_run; then
      # 기존 파일들 읽기
      WHY=""
      PLAN=""
      CONTRACT=""
      PROGRESS=""
      VERDICT=""
      STARTED=""

      # spec에서 Why 추출
      SPEC="$DEST_DIR/docs/product-specs/${TRACK}.md"
      if [[ -f "$SPEC" ]]; then
        WHY=$(awk '/^## 왜/{found=1; next} found && /^##/{exit} found{print}' "$SPEC" | sed '/^$/d' | head -5)
        STARTED=$(grep '^started:' "$SPEC" 2>/dev/null | head -1 | sed 's/started: *//' || true)
      fi
      [[ -z "$STARTED" ]] && STARTED=$(date -u +%Y-%m-%d)

      # plan.md
      if [[ -f "$d/plan.md" ]]; then
        PLAN=$(grep -E '^\- \[' "$d/plan.md" 2>/dev/null || true)
      fi

      # sprint-contract.md → Contract
      if [[ -f "$d/sprint-contract.md" ]]; then
        CONTRACT=$(cat "$d/sprint-contract.md" | grep -v '^---' | grep -v '^name:' | head -20 || true)
      fi

      # progress.md → Log
      if [[ -f "$d/progress.md" ]]; then
        PROGRESS=$(grep -v '^#' "$d/progress.md" | grep -v '^$' | head -10 || true)
      fi

      # evaluation.md → Verdict
      if [[ -f "$d/evaluation.md" ]]; then
        VERDICT=$(grep 'APPROVED\|CHANGES_REQUESTED\|BLOCKED' "$d/evaluation.md" | head -1 || true)
      fi

      # 단일 파일 생성
      cat > "$OUT" <<EOF
---
track: ${TRACK}
status: active
started: ${STARTED}
migrated-from: v1
---

## Why
${WHY:-_(spec 없음 — 직접 채우세요)_}

## Plan
${PLAN:-_(plan.md 없음)_}

## Contract
${CONTRACT:-_(sprint-contract.md 없음)_}

## Log
${PROGRESS:-_(progress.md 없음)_}

## Verdict
${VERDICT:-}
EOF

      # Track.md 인덱스에 등록
      if [[ -f "$TRACK_INDEX" ]]; then
        if ! grep -q "$TRACK" "$TRACK_INDEX"; then
          sed -i.bak "s|_(비어 있음.*)|&\n- [${TRACK}](tracks/${TRACK}.md)|" "$TRACK_INDEX" && \
            rm -f "${TRACK_INDEX}.bak"
        fi
      fi

      ok "트랙 마이그레이션: $TRACK → tracks/${TRACK}.md"
    else
      log "DRY: $TRACK → tracks/${TRACK}.md (plan+contract+progress+evaluation 통합)"
    fi
  done

  # active/ 디렉터리 제거
  if [[ ${#TRACK_DIRS[@]} -gt 0 ]]; then
    if do_run; then
      rm -rf "$ACTIVE_DIR"
      ok "tracks/active/ 제거"
    else
      log "DRY: tracks/active/ 제거"
    fi
  fi
fi

# completed/ 트랙도 이동
COMPLETED_DIR="$DEST_DIR/.harness/tracks/completed"
if [[ -d "$COMPLETED_DIR" ]]; then
  DONE_DIR="$TRACKS_DIR/done"
  shopt -s nullglob
  for d in "$COMPLETED_DIR"/*/; do
    TRACK=$(basename "$d")
    OUT="$DONE_DIR/${TRACK}.md"
    if do_run; then
      mkdir -p "$DONE_DIR"
      # lessons.md + report.md 있으면 합치기
      cat > "$OUT" <<EOF
---
track: ${TRACK}
status: done
migrated-from: v1
---

## Log
EOF
      [[ -f "$d/lessons.md" ]] && cat "$d/lessons.md" >> "$OUT"
      [[ -f "$d/report.md" ]]  && { echo; echo "---"; cat "$d/report.md"; } >> "$OUT"
      ok "완료 트랙 마이그레이션: $TRACK → tracks/done/${TRACK}.md"
    else
      log "DRY: completed/$TRACK → tracks/done/${TRACK}.md"
    fi
  done
  shopt -u nullglob
  if do_run; then
    rm -rf "$COMPLETED_DIR"
    ok "tracks/completed/ 제거"
  else
    log "DRY: tracks/completed/ 제거"
  fi
fi

# ─── Step 3: 하네스 소유 파일 제거 ───────────────────────────────────────────

log "3/6 구 하네스 파일 제거..."

SAFE_REMOVE=(
  "HARNESS_MAP.md"
  ".harness/linters/memory_schema.py"
  ".harness/skills/ingest-spec"
)

for item in "${SAFE_REMOVE[@]}"; do
  target="$DEST_DIR/$item"
  if [[ -e "$target" ]]; then
    if do_run; then
      rm -rf "$target"
      ok "제거: $item"
    else
      log "DRY: rm -rf $item"
    fi
  fi
done

# .harness/commands/ 디렉터리 (새 commands.md가 이미 설치된 경우에만)
if [[ -d "$DEST_DIR/.harness/commands" && -f "$DEST_DIR/.harness/commands.md" ]]; then
  if do_run; then
    rm -rf "$DEST_DIR/.harness/commands"
    ok "제거: .harness/commands/"
  else
    log "DRY: rm -rf .harness/commands/"
  fi
fi

# ─── Step 4: ARCHITECTURE.md (루트) 처리 ─────────────────────────────────────

log "4/6 ARCHITECTURE.md (루트) 처리..."

ROOT_ARCH="$DEST_DIR/ARCHITECTURE.md"
NEW_ARCH="$DEST_DIR/.harness/ARCHITECTURE.md"

if [[ -f "$ROOT_ARCH" ]]; then
  # 프로젝트별 모듈 표가 채워져 있는지 확인
  CUSTOM_MODULES=$(grep -v '_예시_' "$ROOT_ARCH" | grep -E '^\|[^|]+\|[^|]+\|[^|]+\|' || true)
  if [[ -n "$CUSTOM_MODULES" && -f "$NEW_ARCH" ]]; then
    if do_run; then
      # 모듈 표를 새 ARCHITECTURE.md에 병합
      MODULES=$(awk '/^## 모듈/{found=1} found && /^## /{if(!/^## 모듈/)exit} found{print}' "$ROOT_ARCH" | \
                grep -v '^## 모듈' || true)
      # 새 파일의 "| _예시_ |" 라인을 교체
      TMP="${NEW_ARCH}.tmp.$$"
      python3 - "$NEW_ARCH" "$MODULES" <<'PYEOF' > "$TMP" && mv "$TMP" "$NEW_ARCH"
import sys
content = open(sys.argv[1]).read()
modules = sys.argv[2]
# _예시_ 행을 실제 모듈로 교체
content = content.replace('| _예시_ | service | `src/billing/` | — |', modules.strip())
print(content, end='')
PYEOF
      ok "모듈 표 .harness/ARCHITECTURE.md에 병합 완료"
    else
      log "DRY: 루트 ARCHITECTURE.md 모듈 표 → .harness/ARCHITECTURE.md 병합"
    fi
  fi

  if do_run; then
    rm -f "$ROOT_ARCH"
    ok "제거: ARCHITECTURE.md (루트)"
  else
    log "DRY: rm ARCHITECTURE.md (루트)"
  fi
fi

# ─── Step 5: docs/ (루트) 처리 ───────────────────────────────────────────────

log "5/6 docs/ (루트) 처리..."

ROOT_DOCS="$DEST_DIR/docs"
HARNESS_DOCS="$DEST_DIR/.harness/docs"

if [[ -d "$ROOT_DOCS" ]]; then
  # 하네스 템플릿 파일 목록
  HARNESS_ONLY=("USAGE.md" "DESIGN.md" "RELIABILITY.md" "SECURITY.md"
                "QUALITY_SCORE.md" "CLI_COMPAT.md" "CONTRIBUTING.md"
                "index.md")

  # 하네스 파일이 아닌 것 탐지
  NON_HARNESS=()
  while IFS= read -r -d '' f; do
    rel="${f#$ROOT_DOCS/}"
    name=$(basename "$rel")
    is_harness=0
    for h in "${HARNESS_ONLY[@]}"; do
      [[ "$name" == "$h" ]] && { is_harness=1; break; }
    done
    # design-docs/, product-specs/, references/ 하위도 체크
    [[ "$rel" == design-docs/* || "$rel" == product-specs/* || "$rel" == references/* ]] && is_harness=1
    [[ "$is_harness" == 0 ]] && NON_HARNESS+=("$rel")
  done < <(find "$ROOT_DOCS" -type f -print0)

  if [[ ${#NON_HARNESS[@]} -gt 0 ]]; then
    warn "docs/ 에 프로젝트 고유 파일 발견 — 수동 처리 필요:"
    for f in "${NON_HARNESS[@]}"; do
      printf '    docs/%s\n' "$f"
    done
    warn "→ 프로젝트 docs/를 유지하거나 .harness/docs/로 직접 이동하세요."
  else
    # 하네스 파일만 있으면 안전하게 제거 (새 위치에 이미 있음)
    if do_run; then
      rm -rf "$ROOT_DOCS"
      ok "제거: docs/ (하네스 파일만 있었음, .harness/docs/로 이미 이동)"
    else
      log "DRY: rm -rf docs/ (하네스 파일만 확인됨)"
    fi
  fi
fi

# ─── Step 6: memory/ 처리 ────────────────────────────────────────────────────

log "6/6 memory/ 처리..."

MEMORY_DIR="$DEST_DIR/memory"

if [[ -d "$MEMORY_DIR" ]]; then
  # 샘플 파일만 있는지 확인
  NON_SAMPLE=()
  while IFS= read -r -d '' f; do
    name=$(basename "$f")
    [[ "$name" == *"_sample.md" || "$name" == "MEMORY.md" ]] && continue
    NON_SAMPLE+=("$name")
  done < <(find "$MEMORY_DIR" -type f -print0)

  if [[ ${#NON_SAMPLE[@]} -gt 0 ]]; then
    warn "memory/ 에 실제 메모리 파일 발견:"
    for f in "${NON_SAMPLE[@]}"; do
      printf '    memory/%s\n' "$f"
    done
    warn "→ v2 하네스는 memory/ 없이 동작합니다."
    warn "→ 내용을 검토 후 수동으로 삭제하거나 .harness/docs/에 보관하세요."
  else
    # 샘플만 있으면 바로 제거
    if do_run; then
      rm -rf "$MEMORY_DIR"
      ok "제거: memory/ (샘플 파일만 있었음)"
    else
      log "DRY: rm -rf memory/ (샘플만 확인됨)"
    fi
  fi
fi

# ─── 완료 ────────────────────────────────────────────────────────────────────

echo
if [[ "$DRY_RUN" == 1 ]]; then
  log "DRY RUN 완료 — 실제 변경 없음. '--yes'로 실행하면 적용됩니다."
else
  log "마이그레이션 완료."
  echo
  log "다음 권장 사항:"
  echo "  1. 'harness lint' 실행해서 상태 확인"
  echo "  2. docs/ 또는 memory/ 에 프로젝트 파일이 있으면 수동 정리"
  echo "  3. .harness/Track.md 에서 마이그레이션된 트랙 확인"
  echo "  4. 에이전트 CLI 재시작"
fi
