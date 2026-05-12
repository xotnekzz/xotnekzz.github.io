---
name: lessons-learned
description: 트랙 완료 시 트랙 파일 ## Log 마지막에 회고를 기록하고 done/으로 이동
---

# lessons-learned

## 단계

1. `.harness/tracks/<track>.md`의 `## Plan`, `## Log`, `## Verdict` 읽기
2. `## Log` 끝에 회고 3줄 이내 append:
   - **작동함** — 검증된 접근
   - **놀라움** — 비자명한 발견 (없으면 생략)
   - **다음엔** — 반복 방지 힌트 (없으면 생략)
3. 트랙 파일을 `tracks/done/<track>.md`로 이동
4. `Track.md`에서 `## Active` 링크 제거, `## Done`에 추가

## 금지

- 수정 레시피 저장 금지 — 코드와 git history가 권위
- 전체 Log 덤프 금지; 비자명한 것만 압축
- lessons가 없으면 회고 섹션 생략 (파일 채우기 금지)
