# 스펙: Vercel SSR 전환 + 관리자 패널 (인증 + 마크다운 에디터 + GitHub API)

- **날짜**: 2026-04-01
- **사이클**: #2
- **작성자**: 기획 에이전트

---

## 목표

Astro를 정적(static) 모드에서 SSR(server) 모드로 전환하고, 인증된 사용자(본인)만 접근할 수 있는
관리자 패널(`/admin`)을 추가한다. 관리자 패널에서 마크다운 포스트를 작성하면 GitHub API를 통해
리포지토리에 파일이 커밋되고, Vercel이 자동으로 재배포한다.

**배경:** Cycle 1에서 로컬 마크다운 기반 전환을 완료했다. 이제 사이트에서 직접 글을 쓸 수 있는
관리자 UI가 필요하다. GitHub Pages는 정적 파일만 서빙하므로 Vercel SSR로 호스팅을 전환한다.

---

## 아키텍처

```
브라우저 → Vercel Edge (Astro SSR)
             │
             ├── /admin/*  → 미들웨어(쿠키 검증) → 관리자 페이지
             ├── /api/admin/login  → 비밀번호 검증 → 쿠키 발급
             ├── /api/admin/post   → GitHub API → 리포지토리 커밋 → Vercel 자동 재배포
             └── 나머지 라우트 → 정적처럼 서빙 (hybrid output)
```

---

## 환경 변수 (신규)

| 변수명 | 설명 |
|--------|------|
| `ADMIN_PASSWORD` | 관리자 로그인 비밀번호 |
| `ADMIN_SECRET` | 쿠키 서명용 시크릿 (임의 긴 문자열) |
| `GITHUB_TOKEN` | GitHub Personal Access Token (repo 쓰기 권한) |
| `GITHUB_OWNER` | 리포지토리 소유자 (e.g. `xotnekzz`) |
| `GITHUB_REPO` | 리포지토리 이름 (e.g. `blog`) |

`.env` 예시 (커밋 금지):
```
ADMIN_PASSWORD=my-secret-password
ADMIN_SECRET=long-random-string-here
GITHUB_TOKEN=ghp_xxx
GITHUB_OWNER=xotnekzz
GITHUB_REPO=blog
```

---

## 변경 대상 파일

### 신규 생성
```
src/middleware.ts                        — /admin/* 라우트 쿠키 인증 보호
src/pages/admin/index.astro             — 대시보드 (포스트 목록 + 새 글 버튼)
src/pages/admin/login.astro             — 로그인 폼
src/pages/admin/new.astro               — 새 포스트 작성 폼
src/pages/api/admin/login.ts            — POST: 비밀번호 검증 + 쿠키 발급
src/pages/api/admin/logout.ts           — POST: 쿠키 삭제
src/pages/api/admin/post.ts             — POST: GitHub API로 마크다운 파일 커밋
```

### 수정
```
astro.config.mjs                        — output: 'hybrid', @astrojs/vercel 어댑터 추가
.github/workflows/deploy.yml            — GitHub Pages 배포 제거, Vercel 배포로 교체
package.json                            — @astrojs/vercel 추가
```

---

## 상세 구현 가이드

### 1. `astro.config.mjs` 변경

```js
import vercel from '@astrojs/vercel';

export default defineConfig({
  output: 'hybrid',       // 기본은 정적, 필요한 라우트만 SSR
  adapter: vercel(),
  // 기존 설정 유지 (site, vite, integrations, markdown)
});
```

`output: 'hybrid'` 사용 이유: 블로그 포스트 페이지는 정적으로 유지하고,
`/admin/*`, `/api/admin/*`만 SSR로 동작시킨다.

정적 라우트에는 `export const prerender = true;`가 이미 기본값이므로 변경 불필요.
SSR 라우트(`/admin/*`, `/api/admin/*`)에는 `export const prerender = false;` 명시.

### 2. 인증 방식

- 로그인: `ADMIN_PASSWORD`와 일치하면 쿠키 발급
- 쿠키 값: `ADMIN_SECRET` (고정 시크릿 토큰)
- 미들웨어: `/admin/login` 제외한 `/admin/*` 경로에서 쿠키 값이 `ADMIN_SECRET`과 일치하는지 확인
- 불일치 시: `/admin/login`으로 리다이렉트

쿠키 설정:
```ts
Astro.cookies.set('admin_session', ADMIN_SECRET, {
  httpOnly: true,
  secure: true,
  sameSite: 'strict',
  maxAge: 60 * 60 * 24 * 7, // 7일
  path: '/',
});
```

### 3. `src/middleware.ts`

```ts
import { defineMiddleware } from 'astro:middleware';

export const onRequest = defineMiddleware(async (context, next) => {
  const { pathname } = context.url;
  if (pathname.startsWith('/admin') && pathname !== '/admin/login') {
    const session = context.cookies.get('admin_session')?.value;
    if (session !== import.meta.env.ADMIN_SECRET) {
      return context.redirect('/admin/login');
    }
  }
  return next();
});
```

### 4. 관리자 UI

**`/admin/login`**: 비밀번호 입력 폼 → POST `/api/admin/login`

**`/admin/`**: 대시보드
- `getCollection('posts')`로 현재 포스트 목록 표시
- "새 글 쓰기" 버튼 → `/admin/new`
- 로그아웃 버튼 → POST `/api/admin/logout`

**`/admin/new`**: 새 포스트 작성 폼
- 입력 필드: title, description, date, tags(콤마 구분), category(dev/til/etc), cover(optional), featured(checkbox)
- 마크다운 본문 textarea (preformatted, 최소 400px 높이)
- 저장 버튼 → POST `/api/admin/post`

UI는 기존 TailwindCSS 스타일 유지. 별도 CSS 프레임워크 추가 금지.

### 5. `src/pages/api/admin/post.ts` — GitHub API 연동

새 포스트 저장 시:
1. 프론트매터 생성 (title, description, date, tags, cover, featured)
2. 파일 경로: `src/content/posts/{category}/{slug}.md`
   - slug: title을 kebab-case로 변환 (영문/숫자만, 공백→하이픈)
3. GitHub Contents API로 파일 생성:

```ts
const response = await fetch(
  `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/contents/src/content/posts/${category}/${slug}.md`,
  {
    method: 'PUT',
    headers: {
      'Authorization': `Bearer ${GITHUB_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: `post: ${title}`,
      content: btoa(unescape(encodeURIComponent(fileContent))), // base64
    }),
  }
);
```

4. 성공 시 JSON `{ ok: true, url: '...' }` 반환
5. 실패 시 JSON `{ ok: false, error: '...' }` 반환 (상태코드 500)

### 6. GitHub Actions 배포 변경

기존 GitHub Pages 배포를 제거하고 Vercel 자동 배포로 교체.

**`.github/workflows/deploy.yml`**:
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

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
        env:
          ADMIN_PASSWORD: test
          ADMIN_SECRET: test
          GITHUB_TOKEN: test
          GITHUB_OWNER: test
          GITHUB_REPO: test
```

Vercel 실제 배포는 Vercel 대시보드에서 GitHub 리포지토리 연결로 처리 (GitHub Actions 불필요).
CI workflow는 빌드 오류 감지 목적으로만 유지.

---

## 수용 기준 (Acceptance Criteria)

- [ ] **AC-1**: `npm run build`가 오류 없이 성공한다 (ADMIN_PASSWORD, ADMIN_SECRET, GITHUB_TOKEN, GITHUB_OWNER, GITHUB_REPO 환경변수 필요)
- [ ] **AC-2**: `npx tsc --noEmit`이 타입 오류 없이 통과한다
- [ ] **AC-3**: `/admin/login` 페이지가 렌더링되며 비밀번호 입력 폼(`<input type="password">`)이 존재한다
- [ ] **AC-4**: 올바른 비밀번호 입력 시 `/admin/` 대시보드로 리다이렉트된다
- [ ] **AC-5**: 잘못된 비밀번호 입력 시 로그인 페이지에 오류 메시지가 표시된다
- [ ] **AC-6**: 쿠키 없이 `/admin/` 접근 시 `/admin/login`으로 리다이렉트된다
- [ ] **AC-7**: `/admin/` 대시보드에 현재 포스트 목록과 "새 글 쓰기" 버튼이 표시된다
- [ ] **AC-8**: `/admin/new` 페이지에 title, description, date, tags, category, 본문 textarea가 존재한다
- [ ] **AC-9**: 기존 블로그 라우트(`/`, `/blog/`, `/tags/`, `/rss.xml`)가 정상 동작한다 (regression)
- [ ] **AC-10**: `ADMIN_PASSWORD`, `ADMIN_SECRET`이 빌드 결과물 또는 클라이언트 JS에 노출되지 않는다

---

## 테스트 시나리오

### 정상 케이스
- 올바른 비밀번호로 로그인 → 대시보드 접근 → `/admin/new`에서 포스트 작성 → 저장 버튼 클릭 → GitHub API 호출 성공 응답 확인

### 엣지 케이스
- 빈 비밀번호로 로그인 시도
- 로그인 후 쿠키를 수동 삭제 후 `/admin/` 재접근 → 로그인 페이지로 리다이렉트
- title에 한글, 특수문자 포함 시 slug 생성 오류 없음

---

## 이번 사이클에서 하지 않는 것

- 기존 포스트 편집 기능 (`/admin/edit/[slug]`)
- 포스트 삭제 기능
- 마크다운 미리보기 (실시간 렌더링)
- 이미지 업로드
- Vercel 실제 배포 확인 (로컬 빌드 성공까지만)
- 댓글, 검색, 페이지네이션

---

## 보안

- `ADMIN_PASSWORD`, `ADMIN_SECRET`, `GITHUB_TOKEN`은 서버 전용 환경변수 — 클라이언트 JS에 절대 노출 금지
- 쿠키는 `httpOnly: true`, `secure: true`, `sameSite: 'strict'` 설정 필수
- GitHub API 호출은 서버 사이드(`/api/admin/post.ts`)에서만 수행
- `astro.config.mjs`의 `env.schema`에 위 환경변수를 `context: 'server', access: 'secret'`으로 등록
