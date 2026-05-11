---
track: content-visibility
outcome: APPROVED
iterations: 1
started: 2026-04-22T00:00:00Z
ended: 2026-04-22T23:30:00Z
---

## 요약

`src/content`(posts, portfolio) 콘텐츠에 `draft: boolean` frontmatter 속성을 추가하여 공개/비공개 제어를 구현했다. Astro content collection 스키마(`src/content.config.ts`)에 기본값 false로 필드 추가, 단일 유틸 `src/lib/content-visibility.ts`에 필터 로직을 집중시키고 7개 페이지와 3개 컴포넌트에서 재사용했다. 프로덕션 빌드에서는 draft가 목록/상세/RSS/sitemap/태그 집계에서 완전히 제외되고, DEV 모드에서는 DRAFT 배지와 함께 노출되어 작성 경험을 보존한다. 단 1회 반복으로 Evaluator APPROVED 획득.

## 반복 내역

| iter | 수행 | 통과 | 실패 | 비고 |
|---|---|---|---|---|
| 1 | plan 19/19 박스 (샘플 정리 step 8만 Evaluator 이후로 연기) | 성공 기준 전부 | 0 | `npm run build` OK, draft 누출 grep 0건 |

## 최종 평가

**Verdict: APPROVED** — `evaluation.md` 참조.

핵심 통과 항목:
- `npm run build` 54 pages, draft 경로(`blog/dev/draft-sample/`, `portfolio/dataengineering/draft-sample/`, `tags/draft-only-tag/`) 모두 미생성
- `dist/` 전체에서 `draft-sample`, `draft-only-tag`, `DRAFT` 문자열 0건
- RSS/sitemap에 draft 누출 0건
- 7개 페이지 + 3개 컴포넌트가 유틸 함수 사용 (중복 조건 없음)
- 타입체크: 트랙 관련 신규 오류 0
- 하네스 린터 5종 전체 통과

## 학습 (lessons.md 요약)

- 단일 유틸 집중화로 회귀 위험 최소화
- DEV/PROD 분기 규칙: 페이지는 DEV 노출(+배지), RSS만 DEV도 예외 제외
- 기본값 `draft: false`로 기존 글 마이그레이션 불필요
- `grep -r dist/`는 정적 사이트 누출 테스트의 값싼 확실한 수단

## 다음 행동

완료. 추가 작업 없음. 검증용 draft 샘플 파일 2개는 승인 후 정리 완료 (`src/content/posts/dev/draft-sample.md`, `src/content/portfolio/DataEngineering/draft-sample.md` 삭제, 재빌드 확인).

콘텐츠 작성 시 사용법:
```yaml
---
title: "예시"
draft: true  # 또는 생략/false → 공개
---
```
