# 스펙: Vercel SSR 제거 → GitHub Pages 정적 관리자 패널

- **날짜**: 2026-04-01
- **사이클**: #3
- **작성자**: 기획 에이전트

---

## 목표

Vercel SSR 구조를 제거하고 GitHub Pages 정적 배포로 되돌린다. 관리자 패널은
서버 없이 브라우저 JS에서 직접 GitHub API를 호출하는 방식으로 재구현한다.

**배경:** Cycle 2에서 Vercel SSR을 도입했으나 오버스펙. 개인 블로그 규모에서는
브라우저 → GitHub API → GitHub Actions → GitHub Pages 흐름으로 충분하다.

---

## 변경 대상 파일

### 삭제
```
src/middleware.ts                  — 서버사이드 인증 미들웨어
src/pages/api/                     — 서버 API 라우트 전체 (login, logout, post)
```

### 수정
```
astro.config.mjs                   — output/adapter/env.schema 제거 → 순수 정적 설정으로 복원
package.json                       — @astrojs/vercel 제거
src/pages/admin/login.astro        — 서버사이드 → 순수 정적 HTML (클라이언트 JS)
src/pages/admin/index.astro        — 서버사이드 → 순수 정적 HTML (클라이언트 JS)
src/pages/admin/new.astro          — 서버사이드 → 순수 정적 HTML (클라이언트 JS)
src/pages/blog/[...slug].astro     — prerender = true 제거
src/pages/blog/index.astro         — prerender = true 제거
src/pages/index.astro              — prerender = true 제거
src/pages/rss.xml.ts               — prerender = true 제거
src/pages/tags/[tag].astro         — prerender = true 제거
src/pages/tags/index.astro         — prerender = true 제거
src/pages/404.astro                — prerender = true 제거
.github/workflows/deploy.yml       — CI 전용 → GitHub Pages 배포로 복원
```

---

## 관리자 패널 동작 방식

```
[브라우저]
  1. /admin/ 접속
  2. GitHub PAT 입력 → sessionStorage에 저장
  3. 글 작성 폼 입력
  4. "저장" 클릭 → fetch(GitHub Contents API, PUT)
  5. 커밋 성공 → GitHub Actions 트리거 → 1~2분 후 페이지 반영
```

### 인증
- PAT 입력창 → `sessionStorage.setItem('github_pat', value)` 저장
- 이후 모든 API 호출에 `Authorization: Bearer <pat>` 헤더 사용
- 페이지 로드 시 `sessionStorage`에 PAT 있으면 로그인 상태로 간주
- 로그아웃: `sessionStorage.removeItem('github_pat')`

### GitHub API 호출 (클라이언트 JS)

```js
// 새 포스트 생성
await fetch(`https://api.github.com/repos/${owner}/${repo}/contents/src/content/posts/${category}/${slug}.md`, {
  method: 'PUT',
  headers: {
    'Authorization': `Bearer ${pat}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    message: `post: ${title}`,
    content: btoa(unescape(encodeURIComponent(markdownContent))),
  }),
});
```

### 리포지토리 설정 (하드코딩)
`owner`와 `repo`는 admin 페이지에 상수로 하드코딩 (공개 정보이므로 문제없음):
```js
const REPO_OWNER = 'xotnekzz';
const REPO_NAME = 'xotnekzz.github.io';
```

---

## astro.config.mjs 최종 형태

```js
// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://xotnekzz.github.io',
  vite: { plugins: [tailwindcss()] },
  integrations: [sitemap()],
  markdown: {
    shikiConfig: { theme: 'github-dark' },
  },
});
```

---

## .github/workflows/deploy.yml 최종 형태

```yaml
name: Deploy Blog to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-pages-artifact@v3
        with:
          path: dist/

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/deploy-pages@v4
        id: deployment
```

---

## 수용 기준 (Acceptance Criteria)

- [ ] **AC-1**: `npm run build`가 환경변수 없이 오류 없이 성공한다
- [ ] **AC-2**: `npx tsc --noEmit`이 타입 오류 없이 통과한다
- [ ] **AC-3**: `astro.config.mjs`에 `output`, `adapter`, `env.schema`가 없다
- [ ] **AC-4**: `package.json`에 `@astrojs/vercel`이 없다
- [ ] **AC-5**: `src/middleware.ts`, `src/pages/api/`가 존재하지 않는다
- [ ] **AC-6**: `/admin/` 페이지가 정적으로 렌더링된다 (브라우저에서 PAT 입력창 표시)
- [ ] **AC-7**: PAT 입력 후 `/admin/new`에서 포스트 작성 폼이 표시된다
- [ ] **AC-8**: 기존 블로그 라우트(`/`, `/blog/`, `/tags/`, `/rss.xml`)가 정상 동작한다
- [ ] **AC-9**: `dist/` 빌드 결과물이 순수 정적 파일로만 구성된다

---

## 이번 사이클에서 하지 않는 것

- 실제 GitHub API 호출 테스트 (PAT 없이 로컬에서 불가)
- Vercel 프로젝트 연결 해제 (사용자 직접 수행)
- 마크다운 미리보기
- 이미지 업로드
