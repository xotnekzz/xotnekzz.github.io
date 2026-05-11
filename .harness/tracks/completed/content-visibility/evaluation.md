# Evaluation — content-visibility (iter 1)

date: 2026-04-22
evaluator: Evaluator agent

## 실행 요약
- `npx astro sync` 성공 (types 생성 1.03s)
- `npx tsc --noEmit` 트랙 관련 신규 오류 0건 (기존 `astro.config.mjs(10,11)` TS7006만 잔존, 본 트랙 무관)
- `npm run build` 성공 — 54 page(s), sitemap 생성 완료
- 프로덕션 dist/ 전수 grep 모두 0건
- 하네스 린터 5종 모두 exit 0 (트랙 무관 기존 warn만)

## Passed
- **스키마**: `src/content.config.ts`의 `posts`, `portfolio` 둘 다 `draft: z.boolean().default(false)` 추가됨 (13, 25행).
- **공용 유틸**: `src/lib/content-visibility.ts`에 `isVisible` / `filterVisible` / `isDraft` / `isPublished` 모두 export 확인.
- **페이지 7개 필터 적용**: `blog/index.astro`, `blog/[...slug].astro`, `portfolio.astro`, `portfolio/[category]/[slug].astro`, `tags/index.astro`, `tags/[tag].astro`, `rss.xml.ts` 모두 `content-visibility` import 확인.
- **RSS 정책**: `rss.xml.ts`가 `isPublished`(DEV 무시)를 사용하여 draft가 피드에 절대 실리지 않음.
- **빌드 산출물**:
  - `grep -r "draft-sample" dist/` → 0건
  - `grep -r "draft-only-tag" dist/` → 0건
  - `grep -E "draft-sample|draft-only-tag" dist/sitemap-*.xml` → 0건
  - `grep -E "draft-sample|draft-only-tag" dist/rss.xml` → 0건
  - `dist/blog/dev/draft-sample/`, `dist/portfolio/dataengineering/draft-sample/`, `dist/tags/draft-only-tag/` 경로 모두 미생성 (ls 확인).
- **DEV 배지 프로덕션 누출 없음**: `grep -rn "DRAFT" dist/` → 0건. 컴포넌트(`PostCard.astro`, `PostListItem.astro`, `PortfolioTabs.astro`)가 모두 `import.meta.env.DEV` 가드 사용 확인.
- **무변경 보장**: 기존 모든 `.md` frontmatter에 `draft` 필드 없으며 기본값 false 덕분에 빌드 목록(54 page)에 모두 유지됨.
- **타입 안전**: `tsc --noEmit` 트랙 관련 오류 0.
- **템플릿**: `_templates/blog-post.md`, `_templates/portfolio.md` 모두 `draft: false` + 안내 주석 포함.
- **검증 샘플**: `posts/dev/draft-sample.md`, `portfolio/DataEngineering/draft-sample.md` 존재, frontmatter 올바름 (draft: true, 전자는 `draft-only-tag` 포함).
- **린터**: arch_layers, memory_schema, agents_md_size, doc_freshness, doc_gardener_scan 모두 본 트랙 관련 실패 없음.
- **Sitemap 정책**: `astro.config.mjs` 수정 없이도 getStaticPaths 제외만으로 sitemap 누락 확인 (spec 가정 5 검증됨).

## Failed
(없음)

## 관측 사항 (차단 아님)
- `dist/sitemap-0.xml`/`sitemap-index.xml`이 실제로 생성되는지 빌드 로그로 확인됨. grep 결과 0건.
- DEV 스모크(`npm run dev` 브라우저 접속)는 직접 실행하지 않았으나, 코드/빌드 산출물 검증상 DEV 경로는 `isVisible`이 `import.meta.env.DEV ? true : …`로 작동하도록 명시되어 있어 로직상 보장됨. Implementer progress.md 7.2에 수동 OK 기록 있음.
- 검증용 샘플 2개는 sprint-contract "Implementer 가정 6"에 따라 Evaluator 승인 후 정리 예정 — 본 평가 기준으로는 유지 상태가 의도된 것.

## Verdict: APPROVED
