# Plan — content-visibility

각 단계는 체크박스, layer 태그, verify 라인을 포함한다. 파일 경로는 절대/리포 상대
기준으로 명시한다.

## 0. 사전 조사 (Implementer 확인)
- [x] **layer: types** — 빌드 명령 확인: `package.json`의 `build`, `dev`, `check`(있으면) 스크립트 이름 확정.
  - verify: `cat package.json | jq .scripts` 로 스크립트명 기록.
- [x] **layer: repo** — 기존 문서에 `draft`/`published`/`visibility` 필드 재확인(0건이어야 함).
  - verify: `rg '^(draft|published|visibility):' src/content` 출력 0줄.

## 1. 스키마 확장
- [x] **layer: types** — `src/content.config.ts`의 `posts`, `portfolio` 스키마 둘 다에 `draft: z.boolean().default(false)` 추가.
  - verify: `npx astro sync` 후 `.astro/content.d.ts`에서 `draft` 필드가 두 컬렉션 entry type에 포함되는지 확인.
- [x] **layer: repo** — 검증용 샘플 draft 파일 2개 생성:
  - `src/content/posts/dev/draft-sample.md` (frontmatter `draft: true`, 태그에 "draft-only-tag" 추가)
  - `src/content/portfolio/DataEngineering/draft-sample.md` (frontmatter `draft: true`)
  - verify: `npx astro sync` 타입 에러 없음. 두 파일은 트랙 종료 시 삭제 대상(체크리스트 마지막 단계 참조).

## 2. 공용 필터 유틸 추가
- [x] **layer: service** — `src/lib/content-visibility.ts` 신규 생성. export:
  - `isVisible(entry): boolean` — `import.meta.env.DEV ? true : !entry.data.draft`
  - `filterVisible<T>(entries: T[]): T[]` — 위 조건으로 필터링하는 헬퍼
  - `isDraft(entry): boolean` — 배지 렌더용, DEV 여부와 무관하게 `entry.data.draft === true`
  - verify: 파일 생성 후 `npx tsc --noEmit`(또는 `astro check`) 통과.

## 3. 페이지별 필터 적용
- [x] **layer: ui** — `src/pages/blog/index.astro`
  - `getCollection('posts')` 결과에 `filterVisible` 적용.
  - `PostListItem` 호출부에 `isDraft(post)` prop 전달 (또는 같은 파일 안에서 배지 렌더).
  - verify: `npm run dev` 후 브라우저에서 draft 샘플이 "DRAFT" 배지와 함께 보임. `npm run build && grep -r "draft-sample" dist/blog/index.html` 결과 없음.
- [x] **layer: ui** — `src/pages/blog/[...slug].astro`
  - `getStaticPaths` 안에서 `filterVisible` 적용.
  - verify: `npm run build` 후 `dist/blog/dev/draft-sample/` 경로 미생성.
- [x] **layer: ui** — `src/pages/portfolio.astro`
  - `portfolioEntries`를 `filterVisible`로 필터링 후 매핑. (기존 title/date 필수 필터 유지.)
  - `PortfolioTabs` 쪽에 draft 배지 노출이 필요하면 `isDraft` 결과를 projects 객체에 포함(DEV 전용).
  - verify: `npm run build && grep -r "draft-sample" dist/portfolio/index.html` 결과 없음. 프로덕션 빌드에는 없음.
- [x] **layer: ui** — `src/pages/portfolio/[category]/[slug].astro`
  - `getStaticPaths`에서 `filterVisible` 적용.
  - verify: `npm run build` 후 `dist/portfolio/dataengineering/draft-sample/` 경로 미생성.
- [x] **layer: ui** — `src/pages/tags/index.astro`
  - 태그 집계 직전에 `filterVisible(posts)` 적용. 카운트가 draft 태그를 세지 않음.
  - verify: draft 샘플에만 달린 `draft-only-tag`가 프로덕션 빌드 `/tags/` 페이지에 나타나지 않음.
- [x] **layer: ui** — `src/pages/tags/[tag].astro`
  - `getStaticPaths`에서 `filterVisible(posts)` 선적용 후 tagMap 구성. 글 0개인 태그는 자연 탈락.
  - 개별 tag 페이지의 posts 목록도 visible만.
  - verify: `npm run build`에서 `dist/tags/draft-only-tag/` 경로 미생성.
- [x] **layer: runtime** — `src/pages/rss.xml.ts`
  - `getCollection('posts')` 결과에 `filterVisible` 적용.
  - 주의: RSS는 프로덕션 배포 산출물이므로 DEV 예외 없이 `!entry.data.draft`만 써야 맞다. `content-visibility.ts`에 `isPublished(entry): boolean`(= `!entry.data.draft`, DEV 무시)을 함께 export해 여기서 사용.
  - verify: `npm run build` 후 `dist/rss.xml`에 draft 항목 미포함.

## 4. 배지 UI (DEV 한정)
- [x] **layer: ui** — `src/components/PostListItem.astro`, `src/components/PostCard.astro`, `src/components/PortfolioTabs.astro` 중 실제 목록 카드 컴포넌트에 draft 배지 렌더.
  - 렌더 조건: `import.meta.env.DEV && isDraft`
  - 시각: 작은 라벨("DRAFT"), 기존 컬러 토큰 사용(`--color-accent` 등).
  - verify: `npm run dev`에서 draft 샘플에만 배지 노출, 프로덕션 빌드 HTML에는 `DRAFT` 문자열 검색 결과 0.

## 5. 템플릿 / 문서 업데이트
- [x] **layer: repo** — `src/content/_templates/blog-post.md` frontmatter에 `draft: false` 라인 추가 + 주석("true로 설정 시 사이트에 노출되지 않음").
- [x] **layer: repo** — `src/content/_templates/portfolio.md`에도 동일 처리.
  - verify: 새 문서 생성 워크플로우에서 draft 필드가 기본적으로 들어가는지 작성자 체크.

## 6. Sitemap 확인
- [x] **layer: config** — `astro.config.mjs`는 수정 불필요. getStaticPaths 제외로 페이지가 아예 생성되지 않기 때문.
  - verify: `dist/sitemap-0.xml`에서 draft 항목 URL 미검출(`grep draft-sample dist/sitemap-*.xml` 빈 결과).

## 7. E2E 검증
- [x] **layer: runtime** — 풀 빌드 검증 시나리오:
  1. `npm run build`
  2. `grep -r "draft-sample" dist/` → 0건
  3. `grep -r "draft-only-tag" dist/tags/` → 0건
  4. `cat dist/rss.xml | grep draft-sample` → 0건
  5. `cat dist/sitemap-0.xml | grep draft-sample` → 0건
  - verify: 위 5개 grep 모두 공집합.
- [x] **layer: runtime** — 개발 모드 시나리오:
  1. `npm run dev`
  2. `/blog/`, `/portfolio/`에서 draft 샘플 + DRAFT 배지 가시성 확인
  3. `/blog/dev/draft-sample/`, `/portfolio/dataengineering/draft-sample/` 상세 접근 성공
  - verify: 스크린샷 또는 수동 OK 기록.

## 8. 정리
- [ ] **layer: repo** — 트랙 승인 후 검증용 draft 샘플 2개 삭제(또는 리포에 영구 보존할지 결정 — Evaluator와 협의).
  - verify: 최종 커밋에서 해당 파일 처리 명시.
