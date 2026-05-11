---
track: content-visibility
owner: tskim
status: draft
created: 2026-04-22
---

# 콘텐츠 공개/비공개 속성

## 왜
`src/content/posts`, `src/content/portfolio` 하위 마크다운 중 일부를 초안/비공개
상태로 관리하고 싶다. 지금은 frontmatter에 해당 필드가 없어, 완성되지 않은 글도
커밋 즉시 사이트에 노출된다. 작성자(tskim)가 "이건 아직 공개하지 않겠다"는 의도를
파일 단위로 표현할 수 있어야 한다.

## 비목표(Non-goals)
- 권한별(로그인 사용자 전용) 콘텐츠 노출 — 이번 트랙은 단순 on/off.
- 예약 발행(스케줄링, 미래 날짜 자동 공개) — 추후 별도 트랙.
- 기존 frontmatter 마이그레이션(모든 문서에 `draft: false`를 강제로 추가하는 작업).
  **기본값 공개**이므로 무변경 = 공개.
- 관리자 UI(`src/pages/admin/`)에서 draft 토글 관리 — 마크다운 편집으로 해결.

## 결정: 필드명
- 기존 문서 전수 조사 결과 `draft / published / visibility` 필드 **전혀 없음**.
- Astro/Obsidian/Jekyll 관례와 일치하는 `draft: boolean`을 채택한다.
- 기본값 `false`(= 공개). `draft: true`일 때만 비공개.

## 동작 정의
1. **목록 제외**
   - `/blog/` (포스트 인덱스) — `draft: true` 제외
   - `/portfolio/` — `draft: true` 제외
   - `/tags/` 인덱스 — draft 포스트의 태그는 집계 카운트에서 제외
   - `/tags/[tag]` — draft 포스트 숨김, 해당 태그에 남는 글이 0개면 태그 경로 자체도 생성하지 않음
2. **상세 페이지 제외 (프로덕션 빌드)**
   - `/blog/[...slug]` `getStaticPaths` 에서 draft 제외
   - `/portfolio/[category]/[slug]` `getStaticPaths` 에서 draft 제외
3. **RSS/Sitemap 제외**
   - `/rss.xml` 에서 draft 제외
   - sitemap은 `@astrojs/sitemap` integration을 쓰므로, 위 getStaticPaths 제외만으로 자동 누락됨. 별도 필터 불필요.
4. **개발 모드 표시**
   - `import.meta.env.DEV === true` 일 때는 draft 항목도 목록/상세에 노출한다.
   - 시각 구분: 목록 카드/아이템에 "DRAFT" 배지 표시(개발 모드 한정).
5. **featured/related/추천**
   - 현재 `featured`는 정렬 우선순위로만 쓰이며 별도 추천/관련 포스트 기능은 미구현. draft 필터를 통과한 항목만 featured 정렬 대상이 된다.

## 수용 기준
- [ ] `src/content.config.ts` 의 `posts`, `portfolio` 스키마에 `draft: z.boolean().default(false)` 추가 (기본값 false).
- [ ] `draft: true`로 표시된 샘플 포스트/포트폴리오 1개씩을 준비해 검증용으로 사용.
- [ ] `npm run build` 실행 시 draft 콘텐츠가 `dist/`에 HTML로 생성되지 않는다.
- [ ] 빌드된 `dist/blog/index.html`, `dist/portfolio/index.html`, `dist/rss.xml`, `dist/sitemap-0.xml` 어디에도 draft 항목이 등장하지 않는다.
- [ ] `dist/tags/index.html`의 태그 카운트가 draft 포스트의 태그를 세지 않는다. draft 포스트에만 달린 태그의 `/tags/<tag>/` 경로는 404이다.
- [ ] 개발 모드(`npm run dev`)에서는 draft 항목이 목록/상세에서 접근 가능하고, 목록에 "DRAFT" 배지가 보인다.
- [ ] `draft` 필드가 없는 기존 모든 문서는 동작 변화가 없다(= 공개 유지).
- [ ] `src/content/_templates/blog-post.md`, `src/content/_templates/portfolio.md` frontmatter에 `draft: false` 주석/필드 안내 추가.
- [ ] `npm run build` 와 `npx tsc --noEmit`(또는 프로젝트의 타입체크 명령) 통과.
