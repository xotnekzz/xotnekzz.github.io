# QA 보고서: Cycle 3 — Vercel SSR 제거 → GitHub Pages 정적 관리자 패널

- **날짜**: 2026-04-01
- **스펙**: `docs/spec/20260401-static-admin.md`
- **검증자**: 검증 에이전트

---

## 수용 기준 결과 요약

| ID | 기준 | 결과 |
|----|------|------|
| AC-1 | `npm run build` 환경변수 없이 성공 | PASS |
| AC-2 | `npx tsc --noEmit` 타입 오류 없음 | PASS |
| AC-3 | `astro.config.mjs`에 `output`, `adapter`, `env.schema` 없음 | PASS |
| AC-4 | `package.json`에 `@astrojs/vercel` 없음 | PASS |
| AC-5 | `src/middleware.ts`, `src/pages/api/` 존재하지 않음 | PASS |
| AC-6 | `/admin/` 정적 렌더링, PAT 입력창 표시 | PASS |
| AC-7 | `/admin/new` 포스트 작성 폼 표시 | PASS |
| AC-8 | 기존 블로그 라우트 정상 동작 | PASS |
| AC-9 | `dist/` 순수 정적 파일 구성 | PASS |

**전체 결과: 9/9 PASS**

---

## 세부 검증 내역

### AC-1: `npm run build` 성공

```
output: "static"
mode: "static"
15 page(s) built in 3.47s
```

환경변수 없이 빌드가 오류 없이 완료됨. `vite` 경고(`matchHostname` 등 미사용 임포트)는 astro 내부 모듈에서 발생하는 것으로 빌드 결과에 영향 없음.

### AC-2: `npx tsc --noEmit`

출력 없음(exit 0) — 타입 오류 없음.

### AC-3: `astro.config.mjs` 내용 확인

```js
export default defineConfig({
  site: 'https://xotnekzz.github.io',
  vite: { plugins: [tailwindcss()] },
  integrations: [sitemap()],
  markdown: { shikiConfig: { theme: 'github-dark' } },
});
```

`output`, `adapter`, `env.schema` 모두 없음. 스펙의 최종 형태와 완전히 일치.

### AC-4: `package.json` 의존성 확인

`dependencies` 및 `devDependencies` 어디에도 `@astrojs/vercel` 없음.

### AC-5: 삭제 대상 파일 확인

- `src/middleware.ts` — 존재하지 않음 (삭제 완료)
- `src/pages/api/` — 존재하지 않음 (삭제 완료)

### AC-6: `/admin/` 정적 렌더링 및 PAT 입력창

- `/admin/login` HTTP 200, 정적 HTML 반환
- 응답에 `<input type="password" id="pat" ...>` 포함
- `GitHub Personal Access Token` 레이블 표시 확인
- 리다이렉트 로직은 클라이언트 JS(`sessionStorage.getItem('github_pat')`)로 구현됨
  - PAT 없을 때 `/admin/login`으로 리다이렉트 (`/admin/index.astro` 및 `/admin/new.astro` 모두 동일 패턴)

### AC-7: `/admin/new` 포스트 작성 폼

HTTP 200, 정적 HTML 반환. 제목/설명/날짜/카테고리/태그/featured/본문 필드 포함한 전체 폼 확인.

### AC-8: 기존 블로그 라우트

| 라우트 | HTTP 상태 |
|--------|-----------|
| `/` | 200 |
| `/blog/` | 200 |
| `/tags/` | 200 |
| `/rss.xml` | 200 |
| `/admin/login` | 200 |
| `/admin/` | 200 |
| `/admin/new` | 200 |

### AC-9: `dist/` 순수 정적 파일

빌드 로그에서 `output: "static"` 확인. `dist/` 내부에 서버 실행 파일(`.mjs`, `server/`) 없음. 생성된 파일 목록:

```
dist/
  _astro/        (번들된 CSS/JS)
  admin/
    index.html
    login/index.html
    new/index.html
  blog/
  tags/
  404.html
  index.html
  rss.xml
  sitemap-index.xml
  sitemap-0.xml
```

---

## prerender 제거 확인

`src/pages/` 전체를 대상으로 `prerender` 키워드 검색 결과 — 매치 없음. 스펙에서 요구한 모든 파일에서 `export const prerender` 제거 완료.

대상 파일:
- `src/pages/blog/[...slug].astro`
- `src/pages/blog/index.astro`
- `src/pages/index.astro`
- `src/pages/rss.xml.ts`
- `src/pages/tags/[tag].astro`
- `src/pages/tags/index.astro`
- `src/pages/404.astro`

---

## CI/CD 워크플로 확인

`deploy.yml`이 스펙의 최종 형태와 일치:
- Vercel 배포 제거
- GitHub Pages 배포 (`actions/upload-pages-artifact@v3` + `actions/deploy-pages@v4`)
- `node-version: '22'` 사용

---

## 비고

- 실제 GitHub API 호출 테스트(PAT 필요)는 이번 사이클 범위 외
- `/admin/` 및 `/admin/new`의 PAT 미존재 시 리다이렉트는 클라이언트 JS로만 동작하므로, 서버 측 리다이렉트는 없음 (정적 사이트 특성상 의도된 설계)
- dev 서버 toolbar에서 `Output: static`, `Adapter: none` 확인됨
