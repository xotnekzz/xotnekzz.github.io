---
name: run-eval
description: 트랙의 Contract 체크를 실행하고 ## Verdict 작성
---

# run-eval

## 단계

1. `.harness/tracks/<track>.md`의 `## Contract` 읽기
2. "Evaluator 체크 항목" 각각에 대해 명령/테스트 실행; 결과 기록
3. `.harness/linters/` 하위 모든 린터 실행; exit 코드 수집
4. 트랙 파일 `## Verdict` 섹션 작성:
   - 통과/실패 항목 (파일:라인)
   - `APPROVED` | `CHANGES_REQUESTED`
5. APPROVED면 exit 0, CHANGES_REQUESTED면 exit 1

## 통합

- 모든 Plan 체크박스 완료 후 `/implement`에서 호출
- PR CI에서 자동 리뷰용으로 호출
