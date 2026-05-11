---
name: lessons-learned
description: 트랙 완료 시 docs/ 또는 memory/에 영속 학습 추출
---

# lessons-learned

## 단계

1. 트랙 완료 시 `plan.md`, `progress.md`, `evaluation.md` 읽기
2. 세 섹션 초안:
   - **작동함** — 검증된 접근
   - **작동 안 함** — 막다른 길과 이유
   - **놀라움** — 비자명한 발견
3. 각 라인을 라우팅:
   - **재사용 패턴** (팀 공유) → `.harness/tracks/completed/<track>/lessons.md`
   - **개인 선호 확정** (세션 수준) → `memory/feedback_<slug>.md`
   - **프로젝트 상태 변경** → `memory/project_<slug>.md`
4. 트랙 폴더를 `active/`에서 `completed/<track>/`으로 이동
5. `docs/product-specs/index.md`에서 활성 링크 제거, 완료 섹션에 추가

## 금지

- 수정 레시피 저장 금지 — 코드와 git history가 권위
- 전체 progress.md 덤프 금지; 비자명한 것만 압축
