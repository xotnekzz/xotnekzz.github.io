# QA 보고서: 사이트 메타데이터 중앙화

- **날짜**: 2026-04-01
- **사이클**: #4
- **스펙 문서**: `docs/spec/20260401-site-metadata.md`
- **검증자**: 검증 에이전트
- **전체 결과**: PASS

---

## 빌드 검증

| 항목 | 결과 | 비고 |
|------|------|------|
| `npm run build` | PASS | 15 page(s) built in 3.25s, 오류 없음 |
| `npx tsc --noEmit` | PASS | 타입 오류 없음 |

---

## 수용 기준 체크리스트

| ID | 수용 기준 | 결과 | 확인 방법 |
|----|-----------|------|-----------|
| AC-1 | `npm run build` 오류 없음 | PASS | 빌드 로그 직접 확인 (15 pages built) |
| AC-2 | `npx tsc --noEmit` 타입 오류 없음 | PASS | tsc 출력 확인 (출력 없음 = 오류 없음) |
| AC-3 | `src/config/site.ts` 존재 및 스펙 구조 일치 | PASS | 파일 직접 읽어 스펙과 대조 |
| AC-4 | `Header.astro`에 navLinks 하드코딩 없고 `SITE.nav` 사용 | PASS | grep 결과 하드코딩 없음, `SITE.nav.map()` 사용 확인 |
| AC-5 | `BaseHead.astro`에 "tskim's dev blog" 리터럴 없고 `SITE.title` 사용 | PASS | grep 결과 리터럴 없음, `SITE.title` 참조 확인 |
| AC-6 | `Footer.astro`가 `SITE.footer.links`와 `SITE.author` 사용 | PASS | `SITE.footer.links.map()`, `SITE.author.name` 사용 확인 |
| AC-7 | `index.astro`가 `SITE.home` 사용 | PASS | `SITE.home.headline`, `SITE.home.tagline` 사용 확인 |
| AC-8 | 헤더 nav에 "홈", "블로그", "태그", "이력서" 4개 링크 렌더링 | PASS | `curl localhost:4321/` HTML 렌더링 결과에서 4개 링크 모두 확인 |

---

## 코드 리뷰

- **스펙 범위 준수**: PASS — 변경 대상 4개 파일(Header.astro, BaseHead.astro, Footer.astro, index.astro)과 신규 파일(src/config/site.ts)만 수정됨
- **보안**: PASS — 환경변수 노출 없음, XSS 위험 없음
- **기존 패턴 일관성**: PASS — import 방식, Astro 컴포넌트 패턴 일관성 유지

---

## 회귀(Regression) 검증

| 라우트 | 결과 | 비고 |
|--------|------|------|
| `/` (홈) | PASS | 헤드라인 "tskim.dev", 태그라인 정상 렌더링 |
| `/blog/` (목록) | PASS | 빌드 시 정상 생성 확인 |
| `/tags/` (태그 인덱스) | PASS | 빌드 시 정상 생성 확인 |
| `/rss.xml` (RSS 피드) | PASS | RSS 피드 내 `<title>tskim's dev blog</title>` 정상 출력 |

---

## 브라우저 검증

`npm run dev` 후 `curl http://localhost:4321/` 로 HTML 렌더링 확인:

- nav 링크 `href="/"`, `href="/blog/"`, `href="/tags/"`, `href="/resume/"` 모두 존재
- 푸터 링크 `href="/rss.xml"`, `href="https://github.com/xotnekzz"` 존재
- 사이트 타이틀 `<title>tskim's dev blog</title>` 정상
- 홈 헤드라인/태그라인 "tskim.dev" 렌더링 확인

---

## 다음 사이클 제안

이번 작업 중 발견한 개선 아이디어 (기획 에이전트에게 전달):

1. `/resume/` 페이지 구현 — 현재 nav에 이력서 링크가 존재하지만 빌드 결과물에 `/resume/index.html`이 생성되지 않아 404 발생 가능. Cycle 5에서 이미 계획된 사항이나 우선순위 높음.
2. `SITE.url`을 `astro.config.mjs`의 `site` 필드와 동기화 — 현재 두 곳이 독립적으로 관리됨. 단일 출처로 통일하면 유지보수 편의성 향상.
