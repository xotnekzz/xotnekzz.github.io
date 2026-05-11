---
command: /implement
description: 트랙의 plan.md 체크박스를 순차 실행하고 Evaluator 승인까지 진행. 중단 시 다음 세션에서 재개 가능.
argument-hint: <트랙 슬러그>
---

# /implement

`.harness/tracks/active/<track>/plan.md`를 단계별 실행. **Implementer · Evaluator 서브에이전트**에 위임한다.

## 단계

1. 로드:
   - `sprint-contract.md` (읽고 가정 확인, 모호하면 사용자에게 질문)
   - `plan.md` (체크박스 파싱)
2. **Implementer 서브에이전트 호출**: `Task` 툴을 `subagent_type="implementer"`로
   호출. 프롬프트에 트랙 슬러그 + plan 경로 + sprint-contract 경로 전달.
   Implementer가 격리된 컨텍스트에서:
   - 미체크 `- [ ]` 박스마다 수행, verify 실행, 체크 표시, `progress.md` 기록
   - 블로커 시 `progress.md`의 `### Blocked`에 기록 후 반환
3. 모든 체크박스 완료 시 **Evaluator 서브에이전트 호출**: `subagent_type="evaluator"`.
   `run-eval` 스킬 로직 실행 → `evaluation.md` 작성, `APPROVED`|`CHANGES_REQUESTED` 반환
4. `APPROVED`면 `lessons-learned` 스킬 호출; 트랙을 `completed/`로 이동
5. `CHANGES_REQUESTED`면 실패 체크만 Implementer 재호출 (메인은 오케스트레이션만)

## 왜 서브에이전트인가

- **컨텍스트 격리**: Implementer는 코드만, Evaluator는 계약만 — 서로 오염 방지
- **토큰 예산**: 긴 구현이 평가 컨텍스트를 밀어내지 않음
- **역할 일관성**: Evaluator는 `tools: Read, Bash, Glob, Grep`로 제한 — Write/Edit 불가
  (프런트매터로 기계 강제)

서브에이전트 미지원 CLI에서는 어댑터가 단일 컨텍스트 롤플레이로 degrade.

## 재개 의미

이전 세션이 `progress.md` + 미체크 박스를 남겼으면 **첫 미체크 박스부터 계속**.
재시작 금지. 완료 단계 재편집 금지.

## 컨텍스트 한계 시 핸드오프

컨텍스트 고갈 전에 `context-reset` 스킬 호출 → 다음 세션이 `handoff.md`로부터 재개.
