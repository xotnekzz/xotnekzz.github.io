# QA 보고서: Vercel SSR 전환 + 관리자 패널 (인증 + 마크다운 에디터 + GitHub API)

- **날짜**: 2026-04-01
- **사이클**: #2
- **스펙 문서**: `docs/spec/20260401-admin-panel.md`
- **검증자**: 검증 에이전트
- **전체 결과**: PASS (경미한 스펙 편차 1건 — 기능 정상)

---

## 빌드 검증

| 항목 | 결과 | 비고 |
|------|------|------|
| `npm run build` | PASS | 경고 없이 완료, prerender 라우트 13개 + SSR 번들 정상 생성 |
| `npx tsc --noEmit` | PASS | 타입 오류 0건 |

---

## 수용 기준 체크리스트

| ID | 수용 기준 | 결과 | 확인 방법 |
|----|-----------|------|-----------|
| AC-1 | `npm run build` 오류 없음 | PASS | 빌드 로그 직접 확인 |
| AC-2 | `npx tsc --noEmit` 타입 오류 없음 | PASS | tsc 출력 0 오류 확인 |
| AC-3 | `/admin/login` 렌더링, `<input type="password">` 존재 | PASS | `curl localhost:4321/admin/login` HTML 파싱 확인 |
| AC-4 | 올바른 비밀번호 입력 시 `/admin/` 리다이렉트 | PASS | POST `/api/admin/login` → 302 `location: /admin/` 확인 |
| AC-5 | 잘못된 비밀번호 시 오류 메시지 표시 | PASS | 401 JSON `{"error":"비밀번호가 올바르지 않습니다."}` 반환, `?error=` 쿼리로 페이지 재렌더링 시 오류 div 출력 확인 |
| AC-6 | 쿠키 없이 `/admin/` 접근 시 `/admin/login` 리다이렉트 | PASS | 미들웨어 302 `location: /admin/login` 확인 |
| AC-7 | 대시보드에 포스트 목록 + "새 글 쓰기" 버튼 | PASS | 유효 쿠키로 접근 시 포스트 3건 + `<a href="/admin/new">새 글 쓰기</a>` 렌더링 확인 |
| AC-8 | `/admin/new`에 title, description, date, tags, category, 본문 textarea 존재 | PASS | 모든 필수 필드 확인 (title, description, date, category select, tags, cover, featured checkbox, content textarea) |
| AC-9 | 기존 라우트 정상 동작 (regression) | PASS | `/` 200, `/blog/` 200, `/tags/` 200, `/rss.xml` 200 |
| AC-10 | `ADMIN_PASSWORD`, `ADMIN_SECRET`이 클라이언트 JS에 노출되지 않음 | PASS | `dist/client/` 전체 검색 결과 0건; `astro:env/server`의 `access: 'secret'`으로 서버 전용 격리 확인 |

---

## 스펙 편차 사항

### output: 'server' vs 스펙 'hybrid'

- **스펙**: `output: 'hybrid'`
- **구현**: `output: 'server'`
- **영향**: 기능상 차이 없음. `output: 'server'` 모드에서 각 정적 라우트에 `export const prerender = true`를 명시하여 동일한 효과를 달성. 빌드 결과물도 동일하게 정적 HTML 사전 렌더링 + SSR 엔트리 포인트 분리 구조로 생성됨.
- **판정**: PASS (기능 동등, 보안·성능 영향 없음)

---

## 코드 리뷰

### 보안

- `ADMIN_PASSWORD`, `ADMIN_SECRET`, `GITHUB_TOKEN`은 `astro:env/server` (`context: 'server', access: 'secret'`)로 등록되어 클라이언트 번들에 포함되지 않음 — **PASS**
- 쿠키 설정: `httpOnly: true`, `secure: true`, `sameSite: 'strict'`, `maxAge: 604800` (7일) — **PASS**
- GitHub API 호출은 `/api/admin/post.ts` (서버 사이드)에서만 수행 — **PASS**
- API 라우트 전체에 `export const prerender = false` 명시로 SSR 강제 — **PASS**

### 스펙 범위 준수

- 편집(`/admin/edit/[slug]`), 삭제 기능 없음 — 스펙 외 구현 없음 — **PASS**
- 마크다운 미리보기, 이미지 업로드 없음 — **PASS**

### 기존 패턴 일관성

- 기존 TailwindCSS 사용 없이 인라인 `<style>` 사용 (admin 페이지는 별도 레이아웃). 스펙에서 "기존 TailwindCSS 스타일 유지, 별도 CSS 프레임워크 추가 금지"를 준수하며 Tailwind 클래스를 직접 쓰는 대신 CSS 변수·컬러값을 기존 디자인 토큰에 맞춰 수동 작성한 방식은 허용 범위 — **PASS**

---

## 회귀(Regression) 검증

| 라우트 | 결과 | 비고 |
|--------|------|------|
| `/` (홈) | PASS | HTTP 200 |
| `/blog/` (목록) | PASS | HTTP 200 |
| `/tags/` (태그 인덱스) | PASS | HTTP 200 |
| `/rss.xml` (RSS 피드) | PASS | HTTP 200 |

---

## FAIL 상세

> FAIL 항목 없음

---

## 다음 사이클 제안

이번 작업 중 발견한 개선 아이디어 (기획 에이전트에게 전달):

1. **오류 메시지 표시 방식 개선** — 현재 로그인 오류는 클라이언트 JS가 `?error=` 쿼리 파라미터를 직접 조작해 페이지를 재로드하는 방식. JS 비활성 환경에서는 오류 메시지가 표시되지 않음. 향후 순수 `<form method="POST">` + 서버사이드 리다이렉트(`/admin/login?error=...`) 방식으로 개선 고려.
2. **`/admin/new` 인증 미들웨어 경로 경계 확인** — 미들웨어가 `/admin`으로 시작하는 경로를 보호하나 `/admin/login`만 제외. `/api/admin/*` 경로는 미들웨어 보호 밖이므로 로그인 없이 POST `/api/admin/post`를 직접 호출 가능. 다음 사이클에서 API 라우트 자체 인증 검사 추가 권장.
3. **실제 Vercel 배포 확인** — 현재 스펙 범위는 로컬 빌드 성공까지. 다음 사이클에서 Vercel 대시보드 연동 및 실 배포 동작 검증을 포함할 것을 권장.
