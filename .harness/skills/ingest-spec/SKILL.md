---
name: ingest-spec
description: 자유 형식 사용자 요청을 docs/product-specs/의 제품 스펙 초안으로 변환
---

# ingest-spec

## 호출 시점

사용자가 스펙 파일 없이 원하는 기능을 서술할 때.

## 단계

1. 핵심 추출: 왜 / 비목표 / 수용 기준
2. 제목 슬러그화 → `<track>`
3. `docs/product-specs/index.md` 템플릿으로 `docs/product-specs/<track>.md` 작성
4. `docs/product-specs/index.md`의 `## 활성` 아래에 링크 추가
5. 트랙 슬러그 반환

## 금지

- 플랜 생성 금지 (그건 `/new-track`의 영역)
- 수용 기준 창작 금지 — 모호하면 사용자에게 질문
