---
name: 샘플 피드백
description: 피드백 메모리 예시 — Why/How-to-apply 구조 시연
type: feedback
---

통합 테스트는 mock이 아니라 실제 데이터베이스를 사용해야 한다.

**Why:** 과거 mock 기반 테스트 스위트가 CI에서 통과한 반면, 프로덕션 마이그레이션이
조용히 깨져 고객 보고로 발견됨.

**How to apply:** `tests/integration/**` 작성 시 `tests/fixtures/db.py`의 fixture 사용;
`db.connect` 패치 금지.
