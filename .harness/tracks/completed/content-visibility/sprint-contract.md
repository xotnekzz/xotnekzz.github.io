# Sprint Contract — content-visibility

Implementer와 Evaluator 간의 협상 기록.

## 성공 기준 (검증 가능/관측 가능)
1. **스키마**: `src/content.config.ts`의 `posts`, `portfolio` 둘 다 `draft: boolean` 필드를 가지며 기본값은 `false`.
2. **프로덕션 빌드(`npm run build`) 산출물 `dist/`**에서 draft 항목이 다음 어디에도 나타나지 않는다:
   - `dist/blog/index.html` 본문
   - `dist/blog/<slug>/index.html` (경로 자체 미생성)
   - `dist/portfolio/index.html` 본문
   - `dist/portfolio/<category>/<slug>/index.html` (경로 자체 미생성)
   - `dist/rss.xml`
   - `dist/sitemap-0.xml` / `dist/sitemap-index.xml`
   - `dist/tags/index.html` (태그 카운트 & 태그 항목)
   - `dist/tags/<draft-only-tag>/...` (경로 자체 미생성)
3. **개발 모드(`npm run dev`)**: draft 항목이 목록/상세에서 접근 가능하고, 목록에 "DRAFT" 배지가 렌더된다.
4. **무변경 보장**: 기존 모든 `.md` 파일은 수정 없이 그대로 공개 상태를 유지한다(기본값 false 덕분).
5. **타입 안전**: `astro check`(또는 `npx tsc --noEmit`) 무오류.
6. 필터 로직은 `src/lib/content-visibility.ts` 한 곳에 모이며, 각 페이지는 이 유틸을 재사용한다(중복 조건문 금지).

## Evaluator 체크 항목
- [ ] `src/content.config.ts` diff에서 두 컬렉션 모두 `draft` 추가됨.
- [ ] `src/lib/content-visibility.ts` 존재, `isVisible` / `filterVisible` / `isDraft` / `isPublished` export.
- [ ] 아래 7개 파일 모두 필터 적용 확인:
  - `src/pages/blog/index.astro`
  - `src/pages/blog/[...slug].astro`
  - `src/pages/portfolio.astro`
  - `src/pages/portfolio/[category]/[slug].astro`
  - `src/pages/tags/index.astro`
  - `src/pages/tags/[tag].astro`
  - `src/pages/rss.xml.ts`
- [ ] RSS는 `isPublished`(DEV 무시 버전) 사용 확인 — 개발 중 실수로 draft가 피드에 실리는 것을 원천 차단.
- [ ] `npm run build` 실행 후 아래 grep 명령 모두 결과 0건:
  - `grep -r "draft-sample" dist/`
  - `grep -r "draft-only-tag" dist/`
- [ ] 배지 구현이 `import.meta.env.DEV` 조건을 걸어, 프로덕션 HTML에 "DRAFT" 문자열이 남지 않음.
- [ ] 템플릿 2개(`_templates/blog-post.md`, `_templates/portfolio.md`)에 `draft: false` 포함.

## Implementer 가정 (확인 필요)
1. **필드명은 `draft`로 확정**. (draft/published/visibility 기존 사용 없음 확인 완료.)
2. **기본값은 공개(`draft: false`)**. 기존 문서 마이그레이션 불필요.
3. **DEV 모드 가시성 정책**: 페이지/목록/상세는 draft도 노출, 단 **RSS만은 DEV에서도 제외**. 이유: RSS 빌드가 프로덕션 피드를 의도하는 단일 목적 파일이기 때문. → Evaluator가 이 정책을 다르게 원하면 `content-visibility.ts`의 한 함수만 바꾸면 된다.
4. **태그 집계 정책**: DEV에서는 draft 포함, 프로덕션에서는 제외. 따라서 `/tags/` 페이지 카운트는 DEV vs PROD에서 달라질 수 있음(의도한 동작).
5. **Sitemap 필터**: `@astrojs/sitemap`의 `filter` 훅을 건드리지 않고, getStaticPaths 제외만으로 해결 가능하다고 가정. (페이지가 빌드 안 되면 sitemap도 자연 누락.) 빌드 결과로 검증.
6. **검증용 draft 샘플 파일**은 PR 머지 전 삭제 또는 유지 — Evaluator 결정.
7. **admin 페이지**(`src/pages/admin/*`)는 draft 관리 기능을 추가하지 않음(범위 외).

## Lint/Verify 명령
```bash
# 타입 체크
npx astro check

# 스키마 동기화
npx astro sync

# 풀 빌드
npm run build

# draft 누출 검증
grep -r "draft-sample" dist/ && echo "FAIL" || echo "OK"
grep -r "draft-only-tag" dist/tags/ && echo "FAIL" || echo "OK"
grep "draft-sample" dist/rss.xml dist/sitemap-*.xml && echo "FAIL" || echo "OK"

# DEV 스모크
npm run dev
# 브라우저로 /blog/, /portfolio/, /blog/dev/draft-sample/ 접속
```
