#!/usr/bin/env bash
# Harness bootstrap. Idempotent. Cross-platform (copy, not symlink).
set -euo pipefail

MODE=""                      # pristine | adopt (자동 감지)
DRY_RUN=0
PROJECT_NAME=""              # 기본: 현재 디렉터리 이름
LANG_HINT="mixed"
STACK_HINT=""
SRC_DIR=""                   # 기본: 이 스크립트 위치로 자동 감지
ASSUME_YES=0
CLI_SELECTION_RAW=""         # --cli 플래그로 건너뛴 선택 ("" = 프롬프트 또는 자동)
KNOWN_ADAPTERS=(claude codex gemini)

usage() {
  cat <<EOF
Usage: init.sh [options]

모든 옵션 생략 가능. 생략 시 스마트 디폴트 + 확인 프롬프트.

Options:
  --project-name <name>   (기본: 현재 디렉터리 이름)
  --mode pristine|adopt   (기본: 빈 디렉터리면 pristine, 아니면 adopt)
  --lang <python|typescript|go|mixed>
  --stack <hint>
  --cli <list>            사용할 CLI 어댑터(쉼표·공백 구분, "none" 가능).
                          예: --cli claude,codex  생략 시 대화식 프롬프트.
  --source <path>         하네스 스켈레톤 루트 (자동 감지)
  --dry-run               변경 없이 프리뷰
  --yes, -y               확인 프롬프트 건너뛰기 (CLI는 감지된 바이너리 사용)
  -h, --help              도움말
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name) PROJECT_NAME="$2"; shift 2 ;;
    --mode)         MODE="$2"; shift 2 ;;
    --lang)         LANG_HINT="$2"; shift 2 ;;
    --stack)        STACK_HINT="$2"; shift 2 ;;
    --dry-run)      DRY_RUN=1; shift ;;
    --source)       SRC_DIR="$2"; shift 2 ;;
    --cli)          CLI_SELECTION_RAW="$2"; shift 2 ;;
    --yes|-y)       ASSUME_YES=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "unknown flag: $1" >&2; usage; exit 2 ;;
  esac
done

DEST_DIR="$(pwd)"

# --- 스마트 디폴트 ---
[[ -z "$PROJECT_NAME" ]] && PROJECT_NAME="$(basename "$DEST_DIR")"

if [[ -z "$SRC_DIR" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SRC_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

if [[ -z "$MODE" ]]; then
  if [[ -f "$DEST_DIR/AGENTS.md" || -f "$DEST_DIR/CLAUDE.md" || -d "$DEST_DIR/src" ]]; then
    MODE="adopt"
  else
    MODE="pristine"
  fi
fi

# 소스와 목적지가 같으면 차단 (자기 자신 덮어쓰기 방지)
if [[ "$(cd "$SRC_DIR" && pwd)" == "$DEST_DIR" ]]; then
  echo "[harness] 에러: source와 dest가 동일합니다. 대상 프로젝트 디렉터리로 이동 후 실행하세요." >&2
  exit 2
fi

# --- CLI 어댑터 선택 ---
# 감지: 바이너리가 PATH에 있거나 기존 .<cli>/ 디렉터리가 있으면 default-on.
detect_clis() {
  local out=""
  for cli in "${KNOWN_ADAPTERS[@]}"; do
    if command -v "$cli" >/dev/null 2>&1 || [[ -d "$DEST_DIR/.$cli" ]]; then
      out+="$cli "
    fi
  done
  echo "${out% }"
}

# 입력 파서: "1,3" / "claude gemini" / "none" / "" → 공백 구분 어댑터 이름.
# $1 = 원본 입력, $2 = 빈 입력일 때 쓸 기본 목록.
parse_selection() {
  local raw="$1" default="$2"
  raw="$(echo "$raw" | tr ',' ' ' | tr '[:upper:]' '[:lower:]')"
  # 빈 입력 → 기본값
  if [[ -z "${raw// /}" ]]; then
    echo "$default"
    return 0
  fi
  # "none" 특수값
  for tok in $raw; do
    if [[ "$tok" == "none" ]]; then echo ""; return 0; fi
  done
  local result=""
  for tok in $raw; do
    local name=""
    case "$tok" in
      1|claude) name="claude" ;;
      2|codex)  name="codex" ;;
      3|gemini) name="gemini" ;;
      *) echo "[harness] 경고: 알 수 없는 CLI 항목 '$tok' 무시" >&2; continue ;;
    esac
    # 중복 제거
    case " $result " in *" $name "*) ;; *) result+="$name " ;; esac
  done
  echo "${result% }"
}

DETECTED="$(detect_clis)"
DEFAULT_IF_NONE_DETECTED="claude"    # 완전히 빈 환경에서의 안전 기본값

# 재실행(upgrade/sync) 시 기존 선택을 존중: config.yaml에 adapters.active가 있으면 그 값 우선.
# "active: []"(빈 리스트, 명시적 none)도 존중 — 값이 있으면 EXISTING_SAVED 설정됨.
EXISTING_SAVED=""
EXISTING_FOUND=0
if [[ -f "$DEST_DIR/.harness/config.yaml" ]]; then
  _saved_line="$(awk '
    /^adapters:/ { in_block=1; next }
    in_block && /^[^ ]/ { in_block=0 }
    in_block && /^[[:space:]]*active:/ { print; exit }
  ' "$DEST_DIR/.harness/config.yaml")"
  if [[ -n "$_saved_line" ]]; then
    EXISTING_FOUND=1
    EXISTING_SAVED="$(echo "$_saved_line" | sed -E 's/.*\[(.*)\].*/\1/' | tr ',' ' ' | tr -s ' ' | sed 's/^ *//; s/ *$//')"
  fi
fi

if [[ -n "$CLI_SELECTION_RAW" ]]; then
  # 플래그 우선. 비어있지 않고 "none"도 아니면 그대로.
  SELECTED_ADAPTERS="$(parse_selection "$CLI_SELECTION_RAW" "$DETECTED")"
elif [[ "$EXISTING_FOUND" == 1 && ( "$ASSUME_YES" == 1 || "$DRY_RUN" == 1 ) ]]; then
  # 비대화식 재실행 — 저장된 선택 유지
  SELECTED_ADAPTERS="$EXISTING_SAVED"
elif [[ "$ASSUME_YES" == 1 || "$DRY_RUN" == 1 ]]; then
  # 비대화식 최초 실행: 감지 결과 사용. 0개면 claude 안전 기본.
  if [[ -n "$DETECTED" ]]; then
    SELECTED_ADAPTERS="$DETECTED"
  else
    SELECTED_ADAPTERS="$DEFAULT_IF_NONE_DETECTED"
  fi
else
  # 대화식 프롬프트. 기본값 우선: 저장된 선택 > 감지 > "claude".
  if [[ "$EXISTING_FOUND" == 1 ]]; then
    prompt_default="${EXISTING_SAVED:-}"
    default_label="저장된 선택 (${prompt_default:-none})"
  elif [[ -n "$DETECTED" ]]; then
    prompt_default="$DETECTED"
    default_label="감지된 CLI ($prompt_default)"
  else
    prompt_default="$DEFAULT_IF_NONE_DETECTED"
    default_label="기본값 ($prompt_default)"
  fi
  echo
  echo "[harness] 사용할 에이전트 CLI를 선택하세요 (복수 선택 가능):"
  for i in 1 2 3; do
    name="${KNOWN_ADAPTERS[$((i-1))]}"
    marks=""
    case " $DETECTED " in *" $name "*) marks+=" [detected]" ;; esac
    case " $EXISTING_SAVED " in *" $name "*) marks+=" [saved]" ;; esac
    printf '  %d) %-7s%s\n' "$i" "$name" "$marks"
  done
  echo "Enter = $default_label / 예: \"1,3\" 또는 \"claude gemini\" / 없음: \"none\""
  read -r -p "> " cli_ans
  # 빈 입력 → prompt_default. parse_selection이 빈 raw면 default 반환.
  if [[ -z "${cli_ans// /}" && "$EXISTING_FOUND" == 1 ]]; then
    # 저장된 선택이 명시적 [] (none)인 경우도 그대로 유지
    SELECTED_ADAPTERS="$prompt_default"
  else
    SELECTED_ADAPTERS="$(parse_selection "$cli_ans" "$prompt_default")"
  fi
fi

# --- 확인 프롬프트 ---
if [[ "$ASSUME_YES" != 1 && "$DRY_RUN" != 1 ]]; then
  cat <<EOF
[harness] 세팅 계획:
  project-name : $PROJECT_NAME
  mode         : $MODE
  lang         : $LANG_HINT
  adapters     : ${SELECTED_ADAPTERS:-(없음)}
  source       : $SRC_DIR
  dest         : $DEST_DIR
EOF
  read -r -p "계속 진행할까요? [Y/n] " ans
  case "${ans:-Y}" in
    y|Y|yes|YES|"") ;;
    *) echo "[harness] 취소됨"; exit 130 ;;
  esac
fi

log()   { printf '[harness] %s\n' "$*"; }
write() {
  local dest="$1" content="$2"
  if [[ "$DRY_RUN" == 1 ]]; then
    if [[ -f "$dest" ]]; then
      log "WOULD update $dest"
    else
      log "WOULD create $dest"
    fi
    return
  fi
  mkdir -p "$(dirname "$dest")"
  printf '%s' "$content" > "$dest"
}

copy_tree() {
  local src="$1" rel="$2"
  local from="$src/$rel" to="$DEST_DIR/$rel"
  [[ -e "$from" ]] || return 0
  if [[ "$DRY_RUN" == 1 ]]; then
    log "WOULD copy $rel/"
    return
  fi
  mkdir -p "$(dirname "$to")"
  # rsync if available; else cp -R
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude='.manifest.local' "$from/" "$to/"
  else
    cp -R "$from/" "$to/"
  fi
}

substitute() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  [[ "$DRY_RUN" == 1 ]] && return 0
  # portable in-place sed
  local tmp="$f.tmp.$$"
  sed -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
      -e "s|{{LANG}}|${LANG_HINT}|g" \
      -e "s|{{STACK}}|${STACK_HINT}|g" \
      "$f" > "$tmp" && mv "$tmp" "$f"
}

log "source: $SRC_DIR"
log "dest:   $DEST_DIR"
log "mode:   $MODE  (dry-run=$DRY_RUN)"

# --- adopt-mode guard: preserve existing top-level docs ---
ADOPT_PRESERVE=(AGENTS.md CLAUDE.md GEMINI.md)
if [[ "$MODE" == "adopt" ]]; then
  for f in "${ADOPT_PRESERVE[@]}"; do
    if [[ -f "$DEST_DIR/$f" ]]; then
      log "adopt: preserving existing $f (will write AGENTS.harness.md instead)"
    fi
  done
fi

# --- copy harness tree ---
for d in .harness .github; do
  copy_tree "$SRC_DIR" "$d"
done

# --- top-level markdown ---
for f in AGENTS.md CLAUDE.md GEMINI.md README.md; do
  if [[ "$MODE" == "adopt" && -f "$DEST_DIR/$f" && "$f" != "README.md" ]]; then
    # write sidecar
    if [[ "$DRY_RUN" == 1 ]]; then
      log "WOULD create ${f%.md}.harness.md (adopt mode)"
    else
      cp "$SRC_DIR/$f" "$DEST_DIR/${f%.md}.harness.md" 2>/dev/null || true
    fi
  else
    if [[ -f "$SRC_DIR/$f" ]]; then
      if [[ "$DRY_RUN" == 1 ]]; then
        log "WOULD write $f"
      else
        cp "$SRC_DIR/$f" "$DEST_DIR/$f"
      fi
    fi
  fi
done

# --- placeholder substitution ---
if [[ "$DRY_RUN" != 1 ]]; then
  while IFS= read -r -d '' f; do
    substitute "$f"
  done < <(find "$DEST_DIR/.harness" \
           -type f \( -name '*.md' -o -name '*.yaml' -o -name '*.yml' \) -print0 2>/dev/null || true)
  for f in AGENTS.md CLAUDE.md GEMINI.md; do
    substitute "$DEST_DIR/$f"
  done
fi

# --- manifest (checksums for idempotency) ---
if [[ "$DRY_RUN" != 1 ]]; then
  MANIFEST="$DEST_DIR/.harness/.manifest"
  : > "$MANIFEST"
  while IFS= read -r -d '' f; do
    rel="${f#$DEST_DIR/}"
    if command -v shasum >/dev/null 2>&1; then
      sha=$(shasum -a 256 "$f" | awk '{print $1}')
    else
      sha=$(sha256sum "$f" | awk '{print $1}')
    fi
    printf '%s  %s\n' "$sha" "$rel" >> "$MANIFEST"
  done < <(find "$DEST_DIR/.harness" -type f -print0 2>/dev/null || true)
  log "manifest: $MANIFEST"
fi

if [[ "$MODE" == "adopt" ]]; then
  PLAN="$DEST_DIR/.harness/tracks/harness-adoption.md"
  if [[ "$DRY_RUN" != 1 ]]; then
    mkdir -p "$(dirname "$PLAN")"
    cat > "$PLAN" <<'EOF'
---
track: harness-adoption
status: active
started: auto
---

## Why
adopt 모드로 하네스 설치. 기존 AGENTS.md/CLAUDE.md 보존, 사이드카(.harness.md)와 병합 필요.

## Plan
- [ ] `config` AGENTS.md vs AGENTS.harness.md diff 후 ToC 병합
- [ ] `config` `.harness/linters/` 중 이 스택에 적용할 린터 선택
- [ ] `config` `.harness/mcp/servers.json` MCP 기본 세트 결정
- [ ] `config` AGENTS.harness.md 사이드카 삭제 (병합 완료 후)

## Contract
성공 기준: AGENTS.md 단일 파일로 통합, harness lint 통과

## Log

## Verdict
EOF
    # Track.md에 adopt 트랙 등록
    TRACK_INDEX="$DEST_DIR/.harness/Track.md"
    if [[ -f "$TRACK_INDEX" ]]; then
      sed -i.bak 's/_(비어 있음 — `\/new-track <설명>`으로 생성)_/- [harness-adoption](tracks\/harness-adoption.md) — adopt 모드 마무리/' "$TRACK_INDEX" && rm -f "${TRACK_INDEX}.bak"
    fi
    log "adopt plan: $PLAN"
  fi
fi

# --- config.yaml에 adapters.active 기록 ---
# init.sh는 치환 이후 이 라인을 직접 갱신해서 재실행 시 사용자 선택 변경을 반영한다.
write_adapters_active() {
  local config="$DEST_DIR/.harness/config.yaml"
  [[ -f "$config" ]] || return 0
  # 공백 구분 → "a, b, c"
  local list_csv
  list_csv="$(echo "$SELECTED_ADAPTERS" | tr -s ' ' | sed 's/ /, /g' | sed 's/^ *//; s/ *$//')"
  local line="  active: [${list_csv}]"
  if grep -q '^adapters:' "$config"; then
    # 기존 adapters 블록의 active 라인 교체 (sed 이식성: 임시파일)
    local tmp="$config.tmp.$$"
    awk -v newline="$line" '
      /^adapters:/ { in_block=1; print; next }
      in_block && /^[^ ]/ { in_block=0 }
      in_block && /^[[:space:]]*active:/ { print newline; replaced=1; next }
      { print }
      END {
        if (!replaced) {
          # adapters 블록은 있었지만 active 키가 없으면 블록 끝에 삽입 못 했으므로 파일 끝에 추가
        }
      }
    ' "$config" > "$tmp" && mv "$tmp" "$config"
  else
    # adapters 섹션이 없으면 파일 끝에 추가
    {
      echo ""
      echo "adapters:"
      echo "  # harness init이 기록. harness sync가 읽어 재컴파일."
      echo "$line"
    } >> "$config"
  fi
}

if [[ "$DRY_RUN" == 1 ]]; then
  log "WOULD set adapters.active = [${SELECTED_ADAPTERS// /, }] in .harness/config.yaml"
else
  write_adapters_active
  log "adapters.active = [${SELECTED_ADAPTERS// /, }]"
fi

# --- 선택된 CLI 어댑터 자동 실행 ---
if [[ "$DRY_RUN" == 1 ]]; then
  for name in $SELECTED_ADAPTERS; do
    log "WOULD compile adapter: $name"
  done
else
  for name in $SELECTED_ADAPTERS; do
    script="$DEST_DIR/.harness/adapters/$name/compile.sh"
    if [[ -x "$script" && -s "$script" ]]; then
      ( cd "$DEST_DIR" && bash "$script" ) || log "$name 어댑터 실패 (계속 진행)"
    elif [[ -f "$script" && -s "$script" ]]; then
      chmod +x "$script" 2>/dev/null || true
      ( cd "$DEST_DIR" && bash "$script" ) || log "$name 어댑터 실패 (계속 진행)"
    else
      log "$name 어댑터 스크립트 없음 또는 비어있음 — 건너뜀. ('harness adapt $name'으로 재시도)"
    fi
  done
fi

log "done."
if [[ -n "$SELECTED_ADAPTERS" ]]; then
  log "슬래시 커맨드/참조가 안 보이면: harness adapt <cli>  (또는 CLI 재시작)"
else
  log "선택된 어댑터 없음. 추후: harness adapt <cli>"
fi
