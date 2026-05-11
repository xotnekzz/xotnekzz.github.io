---
name: autopilot-runner
description: Ralph-style 루프 — Planner/Implementer/Evaluator를 자동 반복하고 report.md 생성
---

# autopilot-runner

`/autopilot` 커맨드의 실행 엔진. 에이전트가 이 스킬을 따라 전체 파이프라인을 돌린다.

## 입력 파싱

1. 위치 인자가 **기존 트랙 슬러그**(= `.harness/tracks/active/<slug>/plan.md` 존재)면 재개.
2. 아니면 자유 설명으로 보고 Planner로 새 트랙 생성.
3. 플래그: `--max-iter N` (기본 5), `--fail-fast`, `--no-plan-edit`, `--report-only`.

## 상태 파일

`.harness/tracks/active/<track>/autopilot-state.json`:
```json
{
  "iteration": 0,
  "max_iter": 5,
  "started": "<ISO>",
  "history": [
    { "iter": 1, "passed": 3, "failed": 1, "files_touched": [...], "duration_s": 42 }
  ],
  "file_edit_counts": { "src/auth.py": 2 },
  "last_evaluation": "APPROVED | CHANGES_REQUESTED"
}
```

## 실행 알고리즘

```
if --report-only:
    → write_report(current_state); return

if 신규 트랙:
    invoke Planner                           # spec + plan + sprint-contract

init autopilot-state.json

while iteration < max_iter:
    iteration += 1
    append "## iter <N>" header to progress.md

    invoke Implementer:
        for each unchecked box in plan.md:
            do it; run its verify; check the box; append to progress.md
            update file_edit_counts; abort if count > 5 for same file (회전문)
        if blocker: write to progress.md ### Blocked; break loop with ABORTED_BLOCKED

    invoke run-eval skill:
        execute each Evaluator check
        run all linters
        write evaluation.md with Passed/Failed/Verdict

    record iteration result in autopilot-state.json.history

    if Verdict == APPROVED:
        break

    if --fail-fast:
        break with ABORTED_FAIL_FAST

    if test regression (passed in prev iter, failed now):
        break with ABORTED_REGRESSION

    if --no-plan-edit:
        break  # 지시만 주고 사람에게 넘김

    # else: 실패 항목을 plan.md에 새 체크박스로 append
    for each failed check in evaluation.md:
        append to plan.md:
          - [ ] [iter <N> fixup] <체크 이름> — <실패 원인 한 줄>
            verify: <원 체크 명령>

# end while

write_report(outcome)
if outcome == APPROVED:
    invoke lessons-learned skill      # 트랙을 completed/로 이동
```

## `write_report(outcome)`

`.harness/tracks/completed/<track>/report.md`(APPROVED) 또는
`.harness/tracks/active/<track>/report.md`(ABORTED) 작성:

```markdown
---
track: <slug>
outcome: <outcome>
iterations: <N>
started: <iso>
ended:   <iso>
---

## 요약
<1 문단: 최종 상태와 그 원인>

## 반복 내역
<autopilot-state.json history를 markdown 표로>

## 최종 평가
<evaluation.md의 Verdict + 실패 항목 링크>

## 학습
<lessons-learned 스킬이 만든 lessons.md 요약; ABORTED면 "완료되지 않아 스킵">

## 다음 행동
<ABORTED별로 구체 제안>
```

## 안전장치 구현

- **회전문 수정 감지**: 동일 파일 `file_edit_counts` ≥ 5이고 해당 파일의 테스트가
  여전히 실패 상태면 `ABORTED_THRASHING`으로 중단
- **테스트 회귀**: 이전 iter `evaluation.md`의 Passed 목록과 현재를 비교. 빠진 항목
  발견 시 즉시 `ABORTED_REGRESSION`
- **시간 상한** (선택): `--time-limit 30m` 가 주어지면 경과 시 중단
- **plan.md 훼손 방지**: 루프는 **append-only**. 사람이 쓴 박스는 수정/삭제 금지.
  fixup 박스는 `[iter N fixup]` 접두어로 식별 가능

## Outcomes

| outcome | 의미 | 트랙 위치 |
|---|---|---|
| `APPROVED` | 정상 종료 | `completed/` |
| `ABORTED_MAX_ITER` | 반복 한도 도달 | `active/` (사람 검토) |
| `ABORTED_FAIL_FAST` | `--fail-fast`로 첫 실패에서 중단 | `active/` |
| `ABORTED_REGRESSION` | 테스트 회귀 발생 | `active/` |
| `ABORTED_THRASHING` | 회전문 수정 감지 | `active/` |
| `ABORTED_BLOCKED` | Implementer가 블로커 기록 | `active/` |

## CLI 훅

`harness run <desc|slug> [...플래그]` 서브커맨드가 이 스킬을 직접 호출하도록 설계.
에이전트 CLI에서는 `/autopilot`으로 트리거.
