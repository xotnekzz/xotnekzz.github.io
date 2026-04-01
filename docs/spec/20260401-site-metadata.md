# 스펙: 사이트 메타데이터 중앙화

- **날짜**: 2026-04-01
- **사이클**: #4
- **작성자**: 기획 에이전트

---

## 목표

사이트 전체에 하드코딩된 텍스트(nav 메뉴, 사이트 제목, 설명, 푸터 링크 등)를
`src/config/site.ts` 단일 파일로 중앙화한다.
이후 텍스트/링크 변경 시 이 파일만 수정하면 된다.

---

## 변경 대상 파일

### 신규 생성
```
src/config/site.ts   — 사이트 전체 메타데이터 상수
```

### 수정
```
src/components/Header.astro     — navLinks 하드코딩 → SITE.nav
src/components/BaseHead.astro   — "tskim's dev blog" 하드코딩 → SITE.title
src/components/Footer.astro     — 링크/copyright → SITE.footer, SITE.author
src/pages/index.astro           — 제목/설명 → SITE.home
```

---

## `src/config/site.ts` 내용

```ts
export const SITE = {
  title: "tskim's dev blog",
  name: "tskim.dev",
  description: "데이터 엔지니어링, 백엔드 개발, 클라우드 인프라에 대한 개발 블로그입니다.",
  url: "https://xotnekzz.github.io",
  author: {
    name: "김태수",
    email: "xotnekzz@gmail.com",
    github: "https://github.com/xotnekzz",
  },
  nav: [
    { href: '/', label: '홈' },
    { href: '/blog/', label: '블로그' },
    { href: '/tags/', label: '태그' },
    { href: '/resume/', label: '이력서' },
  ],
  footer: {
    links: [
      { href: '/rss.xml', label: 'RSS' },
      { href: 'https://github.com/xotnekzz', label: 'GitHub' },
    ],
  },
  home: {
    headline: "tskim.dev",
    tagline: "데이터 엔지니어링 · 백엔드 · 클라우드에 대해 씁니다.",
  },
} as const;
```

---

## 수용 기준 (Acceptance Criteria)

- [ ] **AC-1**: `npm run build`가 오류 없이 성공한다
- [ ] **AC-2**: `npx tsc --noEmit`이 타입 오류 없이 통과한다
- [ ] **AC-3**: `src/config/site.ts`가 존재하며 위 구조를 갖는다
- [ ] **AC-4**: `Header.astro`에 navLinks 하드코딩이 없고 `SITE.nav`를 사용한다
- [ ] **AC-5**: `BaseHead.astro`에 "tskim's dev blog" 문자열이 없고 `SITE.title`을 사용한다
- [ ] **AC-6**: `Footer.astro`가 `SITE.footer.links`와 `SITE.author`를 사용한다
- [ ] **AC-7**: `index.astro`가 `SITE.home`을 사용한다
- [ ] **AC-8**: 헤더 nav에 "홈", "블로그", "태그", "이력서" 4개 링크가 렌더링된다

---

## 이번 사이클에서 하지 않는 것

- `/resume` 페이지 실제 구현 (Cycle 5)
- `astro.config.mjs`의 `site` URL 변경
- 디자인/스타일 변경
