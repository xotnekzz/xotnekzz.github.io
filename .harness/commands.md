# 슬래시 커맨드 정의

각 `## /command` 섹션이 하나의 커맨드. 어댑터가 이 파일을 읽어 CLI별 포맷으로 컴파일한다.

---

## /setup

**description**: 프로젝트 컨텍스트 초기화 (최초 1회) — 스택/워크플로 문서를 대화형으로 생성.

프로젝트 컨텍스트 문서 초기화. 대화형.

### 생성물

- `.harness/docs/DESIGN.md` 스택 섹션 채움
- `.harness/ARCHITECTURE.md` 모듈 표 채움

### 단계

1. 사용자에게 3개 질문, 하나씩:
   - 이 제품은 뭘 하나? 누가 쓰나?
   - 스택은? (언어, 프레임워크, 배포 타깃)
   - 어떻게 출시하나? (브랜치 전략, 리뷰 프로세스, 주기)
2. ARCHITECTURE.md 모듈 표와 DESIGN.md 스택 섹션 채움
3. 확인 메시지: "설정 완료 — 다음: `/new-track <첫 기능>`"

### 규칙

- 가정으로 미리 채우지 않음. 질문하라.

---

## /new-track

**description**: 새 트랙 생성 — 계획 작성 (구현은 안 함). /implement로 이어짐.
**argument-hint**: `<짧은 설명>`

**Planner 서브에이전트**에 위임한다.

### 단계

1. 설명 슬러그화 → `<track>` (소문자, 하이픈, ≤30자)
2. **서브에이전트 호출**: `subagent_type="planner"`. 프롬프트에 track 슬러그 전달.
   Planner가 `.harness/tracks/<track>.md` 생성 (A4 1장 이내).
3. `Track.md`의 `## Active`에 링크 추가
4. 출력:
   ```
   TRACK CREATED: <track>
   plan: .harness/tracks/<track>.md
   NEXT: /implement <track>
   ```

### 가드레일

- 기존 활성 트랙과 슬러그 충돌 시 `-v2` 추가
- 구현 시작 금지 — Planner는 계획만 작성

---

## /implement

**description**: 트랙 Plan 체크박스를 순차 실행하고 Evaluator 승인까지 진행.
**argument-hint**: `<트랙 슬러그>`

**Implementer → Evaluator 서브에이전트**에 위임한다.

### 단계

1. `.harness/tracks/<track>.md` 로드 — `## Plan` 체크박스 파싱, `## Contract` 확인
2. **Implementer 서브에이전트 호출**: 미체크 박스마다 수행, verify 실행, 체크 표시, `## Log`에 한 줄 기록
3. 완료 시 **Evaluator 서브에이전트 호출**: Contract 기준 검증 → `## Verdict` 작성
4. `APPROVED`면 트랙을 `done/`으로 이동, `Track.md` 갱신
5. `CHANGES_REQUESTED`면 실패 항목만 Implementer 재호출

### 재개 의미

이전 세션이 미체크 박스를 남겼으면 첫 미체크 박스부터 계속. 재시작 금지.

---

## /autopilot

**description**: 요청→계획→개발→검증을 자동 반복. 사람 리뷰 없이 트랙 완주.
**argument-hint**: `<설명|트랙슬러그> [--max-iter N] [--fail-fast] [--report-only]`

`/new-track` + `/implement`를 자동 루프로 묶음. Evaluator가 `CHANGES_REQUESTED`를 내면
실패 항목을 Plan에 추가해 다시 Implementer를 돌린다.

### 인자

- `--max-iter N` — 기본 5
- `--fail-fast` — 첫 실패 시 즉시 중단
- `--report-only` — 실행 없이 현재 상태만 출력

### 흐름

```
Planner → [iter 0..max]: Implementer → Evaluator
  APPROVED    → done/으로 이동
  CHANGES_REQ → Plan에 append → 다음 iter
  iter ≥ max  → ABORTED_MAX_ITER
```

### 안전장치

- 동일 파일 5회+ 연속 수정 시 자동 중단 (thrashing 감지)
- 이전 iter 통과 테스트가 새 iter에서 실패 시 즉시 ABORTED

---

## /gc

**description**: doc-gardener 수동 실행 — 문서/코드 드리프트, 고아 트랙 스캔. 기본 dry-run.
**argument-hint**: `[--apply]`

### 단계

1. `.harness/agents/doc-gardener.md` 로드
2. 체크리스트 실행
3. `--apply`면 `auto-gc` 라벨 PR 생성 (주당 5개 캡)

### 안전

- 최근 7일 내 사람이 수정한 파일 건드리지 않음

---

## /lint-harness

**description**: 하네스 건강 검사 — AGENTS.md 사이즈, 레이어, 고아 트랙 등 보고만.

### 검사 항목

1. `AGENTS.md` 라인 ≤ 100 (`.harness/linters/agents_md_size.py`)
2. 아키텍처 린터 실행 가능 (`.harness/linters/arch_layers.py --dry-run`)
3. 문서 신선도 (`.harness/linters/doc_freshness.py`)
4. `Track.md`에 없는 `.harness/tracks/` 고아 트랙
5. `.harness/mcp/servers.json` 중 최근 30일 미사용 MCP

### 출력

```
HARNESS HEALTH: <N passed / M checks>
WARNINGS: ...
ERRORS: ...
```
