---
name: run-eval
description: 주어진 트랙의 모든 Evaluator 체크를 실행하고 evaluation.md 작성
---

# run-eval

## 단계

1. `.harness/tracks/active/<track>/sprint-contract.md` 읽기
2. "Evaluator 체크 항목" 각각에 대해 명령/테스트 실행; 결과 기록
3. `.harness/linters/` 하위 모든 린터 실행; exit 코드 수집
4. `.harness/tracks/active/<track>/evaluation.md` 작성 (Passed/Failed/Verdict)
5. APPROVED면 exit 0, CHANGES_REQUESTED면 exit 1

## 통합

- 모든 플랜 체크박스 완료 후 `/implement`에서 호출
- PR CI에서 자동 리뷰용으로 호출
