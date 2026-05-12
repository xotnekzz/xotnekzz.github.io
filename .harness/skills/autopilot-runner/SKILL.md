---
name: autopilot-runner
description: Ralph-style 루프 — Planner/Implementer/Evaluator를 자동 반복. 트랙 파일 단일 파일로 상태 관리.
---

# autopilot-runner

`/autopilot` 커맨드의 실행 엔진.

## 입력 파싱

1. 위치 인자가 **기존 트랙 슬러그**(= `.harness/tracks/<slug>.md` 존재)면 재개.
2. 아니면 자유 설명으로 보고 Planner로 새 트랙 생성.
3. 플래그: `--max-iter N` (기본 5), `--fail-fast`, `--no-plan-edit`, `--report-only`.

## 실행 알고리즘

```
if --report-only:
    → Log 섹션 출력; return

if 신규 트랙:
    invoke Planner → .harness/tracks/<track>.md 생성

while iteration < max_iter:
    iteration += 1

    invoke Implementer:
        for each unchecked box in ## Plan:
            do it; verify; check box; Log에 한 줄 append
            동일 파일 5회+ 수정 시 ABORTED_THRASHING
        if blocker: Log에 "BLOCKED: <이유>" append; break

    invoke run-eval skill → ## Verdict 작성

    if Verdict == APPROVED: break
    if --fail-fast: break ABORTED_FAIL_FAST
    if 테스트 회귀: break ABORTED_REGRESSION
    if --no-plan-edit: break

    # 실패 항목을 ## Plan에 새 체크박스 append (접두어: [iter N fixup])

# end while

if APPROVED:
    invoke lessons-learned → done/으로 이동, Track.md 갱신
else:
    Log에 최종 상태 기록 (active/ 잔류, 사람 검토)
```

## 안전장치

- **회전문**: 동일 파일 `≥5` 수정 + 테스트 여전히 실패 → ABORTED_THRASHING
- **테스트 회귀**: 이전 iter 통과 항목이 새 iter에서 실패 → ABORTED_REGRESSION
- **Plan append-only**: 사람이 쓴 박스 수정/삭제 금지. fixup 박스는 `[iter N fixup]` 접두어

## Outcomes

| outcome | 의미 | 트랙 위치 |
|---|---|---|
| `APPROVED` | 정상 종료 | `done/` |
| `ABORTED_MAX_ITER` | 반복 한도 도달 | `tracks/` (사람 검토) |
| `ABORTED_FAIL_FAST` | 첫 실패에서 중단 | `tracks/` |
| `ABORTED_REGRESSION` | 테스트 회귀 | `tracks/` |
| `ABORTED_THRASHING` | 회전문 수정 | `tracks/` |
| `ABORTED_BLOCKED` | Implementer 블로커 | `tracks/` |
