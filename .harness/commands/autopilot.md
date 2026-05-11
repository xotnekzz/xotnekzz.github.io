---
command: /autopilot
description: 요청→계획→개발→검증→보고를 자동 반복 (Ralph-style). 사람 리뷰 없이 트랙을 완주하고 report.md 생성.
argument-hint: <설명|트랙슬러그> [--max-iter N] [--fail-fast] [--no-plan-edit] [--report-only]
---

# /autopilot

요청 → 계획 → 개발 → 검증/테스트 → 보고 까지 **자동 반복** (Ralph-style 루프 기반).

`/new-track`·`/implement`·`run-eval`·`lessons-learned`를 하나의 오케스트레이션으로
묶고, Evaluator가 `CHANGES_REQUESTED`를 내면 실패 항목을 plan에 추가해 다시 Implementer를
돌린다. APPROVED 또는 max-iter 도달 시 종료.

## 언제 쓰나

- 스펙이 충분히 명확해 **사람 리뷰 없이** 전 과정을 맡기고 싶을 때
- CI/야간 빌드에서 자동화된 수정 루프가 필요할 때
- 작은 기능 트랙을 빠르게 여러 개 돌릴 때

사람 리뷰가 중요하면 `/new-track` → `/implement`를 따로 쓰세요.

## 인자

- **위치 인자** — 자유 텍스트 설명이면 새 트랙 생성, 기존 슬러그면 재개
- `--max-iter N` — 기본 5. Implementer↔Evaluator 왕복 한도
- `--fail-fast` — 첫 실패 체크 발생 시 즉시 중단 (반복 없음)
- `--no-plan-edit` — Evaluator 실패를 plan에 새 박스로 추가하지 않음(지시만 반환)
- `--report-only` — 실행 없이 현재 트랙 상태로 리포트만 생성

## 실행 흐름 — 서브에이전트 파이프라인

메인 에이전트는 **오케스트레이터**다. 각 단계마다 `Task` 툴(= `Agent`)로 적절한
`subagent_type`을 호출하여 격리된 컨텍스트에서 역할을 수행시킨다.

```
요청
  │
  ▼  Task(subagent_type="planner")
Planner      → spec.md, plan.md, sprint-contract.md 작성 후 반환
  │
  ▼
[iter 0..max]:
  Task(subagent_type="implementer")
    → plan 체크박스 수행, progress.md 기록, 반환
  Task(subagent_type="evaluator")
    → evaluation.md (APPROVED | CHANGES_REQUESTED) 반환
  │
  ├─ APPROVED    → break
  ├─ CHANGES_REQUESTED & iter < max:
  │    failed 항목을 plan.md에 새 체크박스로 append → 다음 iter
  └─ iter ≥ max  → break (중단 플래그)

lessons-learned 스킬  → completed/<track>/lessons.md
report                → completed/<track>/report.md (또는 active/ 잔류)
트랙 이동             → APPROVED일 때만 completed/
```

### 왜 서브에이전트 위임인가

- **컨텍스트 격리**: Planner가 만든 장문의 spec 추론이 Implementer 컨텍스트를 오염시키지 않음
- **토큰 예산 분리**: 각 iter의 Implementer/Evaluator가 독립 예산 (메인 세션 컨텍스트 보존)
- **역할별 툴 제한**:
  - Planner: `Read, Write, Edit, Glob, Grep` (Bash 없음 — 코드 실행 금지)
  - Implementer: 전체 (`Bash` 포함 — 테스트 실행)
  - Evaluator: `Read, Bash, Glob, Grep` (Write/Edit 없음 — 게이트키퍼)
- **병렬 가능성** (향후): 독립 트랙이면 Implementer를 병렬 호출

### 단일 컨텍스트 fallback (서브에이전트 미지원 CLI)

Codex/Gemini 등에서는 어댑터가 롤플레이 모드로 전환 — 메인 에이전트가 각 페르소나
프롬프트를 순차 읽으며 한 컨텍스트에서 수행. 기능은 유지되나 격리 효과는 없음.

## 생성물

- 진행 중: `.harness/tracks/active/<track>/`
  - `plan.md`, `sprint-contract.md`, `progress.md`, `evaluation.md`, `iter-N.log`
- 완료 후: `.harness/tracks/completed/<track>/`
  - 위 파일들 + `lessons.md` + **`report.md`**

### report.md 템플릿

```markdown
---
track: <slug>
outcome: APPROVED | ABORTED_MAX_ITER | ABORTED_FAIL_FAST
iterations: N
started: <ISO>
ended:   <ISO>
---

## 요약
<한 문단>

## 반복 내역
| iter | 수행 | 통과 | 실패 | 비고 |
|---|---|---|---|---|
| 1 | ... | ... | ... | ... |

## 최종 평가
(최종 evaluation.md 링크/요약)

## 학습 (lessons.md 요약)
- ...

## 다음 행동
- ABORTED라면 사람 리뷰 포인트 / 남은 실패 / 권장 수정
```

## 안전장치

- **max-iter 기본 5** — 무한 루프 방지. 도달 시 `ABORTED_MAX_ITER`로 리포트
- **파일 변경 쿨다운** — 동일 파일에 5회+ 연속 수정 시 자동 중단 ("회전문 수정" 감지)
- **테스트 회귀** — 이전 iter에서 통과한 테스트가 새 iter에서 실패하면 즉시 ABORTED
- `/autopilot`는 **plan.md에 사람이 적은 박스는 삭제/재작성하지 않는다** — 항상 append
- `--fail-fast`이 아니면, 블로커는 plan 외부로 나가지 않음 (Implementer의 `### Blocked` 규칙과 동일)

## 예

```
/autopilot 로그인 폼에 OTP 추가
/autopilot user-login --max-iter 3
/autopilot user-login --report-only
/autopilot user-login --fail-fast
```

## 비-자동화 버전과의 차이

|  | `/new-track` + `/implement` | `/autopilot` |
|---|---|---|
| 사람 리뷰 지점 | spec/plan 작성 후 | 없음 (기본) |
| 재시도 | 수동 | 자동 (max-iter) |
| 리포트 | 없음 (lessons.md만) | **report.md 생성** |
| CI 친화 | 낮음 | 높음 |

## 구현 스켈레톤

이 커맨드는 `.harness/skills/autopilot-runner/SKILL.md`를 호출한다. 실제 제어 로직은
그 스킬이 담당하며, 에이전트는 그 스킬을 따라 Planner → Implementer → Evaluator를
반복 호출한다.
