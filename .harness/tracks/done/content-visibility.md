---
track: content-visibility
status: done
migrated-from: v1
---

## Log
---
track: content-visibility
---

## 핵심 학습

- **단일 유틸 집중화**: `src/lib/content-visibility.ts` 하나에 `isVisible / filterVisible / isDraft / isPublished`를 모아 7개 페이지·3개 컴포넌트가 재사용. 중복 조건문 제거로 회귀 위험 최소화.
- **DEV/PROD 분기 규칙 명확화**: 페이지/목록/상세는 DEV에서 draft 노출(+배지), RSS만 예외적으로 DEV에서도 draft 제외. 프로덕션 피드 오염을 원천 차단하면서도 로컬 작성 경험 보존.
- **기본값 = 공개**: `draft: z.boolean().default(false)` — frontmatter 미지정 기존 글은 모두 공개로 유지되어 마이그레이션 불필요.
- **Sitemap은 자동 처리**: `getStaticPaths`에서 draft 제외만으로 sitemap integration이 자동으로 누락. astro.config 수정 불필요.
- **검증 전략**: `grep -r "draft-sample" dist/`, `grep "DRAFT" dist/` 같은 빌드 산출물 grep은 정적 사이트에서 누출 테스트의 값싸고 확실한 수단.

## 다음에 활용할 패턴

1. 콘텐츠 스키마 필드 추가 시: schema 수정 → 유틸 함수화 → 페이지 루프에서 `.filter(util)` 삽입 → 샘플 파일로 grep 검증의 4단계.
2. DEV 가드(`import.meta.env.DEV`)가 필요한 UI는 컴포넌트 수준에서 분기하고, SSR 페이지에서는 props로 내려 공유.

---
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
