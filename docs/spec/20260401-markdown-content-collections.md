# 스펙: Notion CMS → 로컬 마크다운 Content Collections 전환

- **날짜**: 2026-04-01
- **사이클**: #1
- **작성자**: 기획 에이전트

---

## 목표

Notion API 의존성을 완전히 제거하고, 로컬 마크다운 파일(`src/content/posts/{category}/*.md`)을
Astro Content Collections로 관리함으로써 빌드 시 외부 API 호출 없이 정적 사이트를 생성한다.

**배경:** 현재 `npm run build` 시 `NOTION_API_KEY`와 `NOTION_DATABASE_ID` 환경변수가
없으면 빌드가 실패한다. Notion API rate-limit과 이미지 만료 URL 문제도 반복 발생하므로,
콘텐츠를 Git 저장소 내 마크다운 파일로 관리하는 구조로 전환한다.

---

## 변경 대상 파일

### 삭제
```
src/lib/notion.ts           — Notion Client 초기화
src/lib/fetchPosts.ts       — Notion DB 쿼리 기반 fetch
src/lib/notionToHtml.ts     — Notion → HTML 변환 파이프라인
```

### 신규 생성
```
src/content/config.ts                      — Content Collections 스키마 정의
src/content/posts/dev/hello-world.md       — 샘플 포스트 #1
src/content/posts/dev/astro-setup.md       — 샘플 포스트 #2
src/content/posts/til/first-til.md         — 샘플 포스트 #3
```

### 수정
```
astro.config.mjs                    — NOTION_* envField 제거, Shiki 마크다운 설정 추가
src/lib/types.ts                    — BlogPost 타입 유지 또는 CollectionEntry 전환
src/pages/blog/index.astro          — fetchAllPosts → getCollection
src/pages/blog/[slug].astro         — [slug] → [...slug], fetchPostWithBody → getEntry + render()
src/pages/index.astro               — fetchAllPosts → getCollection
src/pages/tags/index.astro          — fetchAllPosts → getCollection
src/pages/tags/[tag].astro          — fetchAllPosts → getCollection
src/pages/rss.xml.ts                — fetchAllPosts → getCollection
src/layouts/PostLayout.astro        — set:html={bodyHtml} → <Content />
package.json                        — @notionhq/client, notion-to-md, unified, remark-*, rehype-* 제거
```

---

## 마크다운 프론트매터 스키마

```yaml
---
title: "포스트 제목"          # string, 필수
description: "요약"           # string, 필수
date: 2026-04-01              # date, 필수
tags: ["astro", "blog"]       # string[], 기본값 []
cover: "/images/cover.jpg"   # string, optional
featured: false               # boolean, 기본값 false
---
```

`src/content/config.ts`:
```ts
import { defineCollection, z } from 'astro:content';

const posts = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string(),
    date: z.coerce.date(),
    tags: z.array(z.string()).default([]),
    cover: z.string().optional(),
    featured: z.boolean().default(false),
  }),
});

export const collections = { posts };
```

---

## 슬러그 처리

`src/content/posts/dev/hello-world.md` → Astro 슬러그: `dev/hello-world`

- `src/pages/blog/[slug].astro` → `src/pages/blog/[...slug].astro` (catch-all 라우트)
- URL: `/blog/dev/hello-world/`
- `getStaticPaths`에서 `params: { slug: post.slug }` 사용

---

## 수용 기준 (Acceptance Criteria)

- [ ] **AC-1**: `npm run build`가 Notion 환경변수 없이 오류 없이 성공한다
- [ ] **AC-2**: `npx tsc --noEmit`이 타입 오류 없이 통과한다
- [ ] **AC-3**: `/blog/` 페이지에 샘플 포스트 3개가 모두 목록에 표시된다
- [ ] **AC-4**: `/blog/dev/hello-world/` 상세 페이지에 마크다운 본문이 HTML로 렌더링된다
- [ ] **AC-5**: 상세 페이지에 `<h2>` 태그로 렌더링된 마크다운 제목이 존재한다
- [ ] **AC-6**: 코드 블록이 Shiki 코드 하이라이팅(`<pre class="astro-code ...">`)으로 렌더링된다
- [ ] **AC-7**: `/tags/` 페이지에 샘플 포스트의 태그가 1개 이상 표시된다
- [ ] **AC-8**: `/rss.xml`에 `<item>` 요소가 1개 이상 포함된다
- [ ] **AC-9**: `src/lib/notion.ts`, `fetchPosts.ts`, `notionToHtml.ts`가 삭제되어 존재하지 않는다
- [ ] **AC-10**: `package.json`에 `@notionhq/client`, `notion-to-md`가 없다

---

## 샘플 포스트

**`src/content/posts/dev/hello-world.md`**
```markdown
---
title: "Hello World"
description: "첫 번째 마크다운 포스트입니다."
date: 2026-04-01
tags: ["astro", "blog"]
featured: true
---

## 환영합니다

이것은 첫 번째 포스트입니다.

## 코드 예시

```python
print("Hello, World!")
```
```

**`src/content/posts/dev/astro-setup.md`**
```markdown
---
title: "Astro Content Collections 설정하기"
description: "Astro 6에서 Content Collections를 설정하는 방법을 정리합니다."
date: 2026-03-28
tags: ["astro", "typescript"]
---

## Content Collections란?

Astro의 타입 안전 콘텐츠 관리 시스템입니다.

```typescript
import { defineCollection, z } from 'astro:content';
```
```

**`src/content/posts/til/first-til.md`**
```markdown
---
title: "TIL: Zod coerce"
description: "z.coerce.date()를 사용하면 문자열 날짜를 자동 변환합니다."
date: 2026-03-25
tags: ["typescript", "zod", "til"]
---

## 오늘 배운 것

`z.coerce.date()`는 문자열을 Date 객체로 자동 변환합니다.
```

---

## 이번 사이클에서 하지 않는 것

- Vercel 배포 전환 (`.github/workflows/deploy.yml` 변경 없음)
- 관리자 패널 / 인증 기능
- 이미지 최적화 (`<Image />` 컴포넌트)
- 페이지네이션
- 카테고리 전용 라우트 (`/category/{name}/`)
- 기존 Notion 포스트 데이터 마이그레이션
- `public/images/notion/` 기존 이미지 정리

---

## 보안

- `NOTION_API_KEY`, `NOTION_DATABASE_ID` 환경변수 불필요 → `astro.config.mjs`에서 `env.schema` 블록 전체 제거
- `.env` 파일에서 NOTION 항목 제거 가능 (`.gitignore`는 유지)
- **개발 에이전트 주의**: `env.schema` 제거 전 `import { NOTION_API_KEY } from 'astro:env/server'` 사용처 모두 삭제 필요
