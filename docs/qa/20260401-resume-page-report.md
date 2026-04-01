# QA 보고서: 이력서 페이지 (/resume)

- **날짜**: 2026-04-01
- **사이클**: #5
- **스펙 문서**: `docs/spec/20260401-resume-page.md`
- **검증자**: 검증 에이전트
- **전체 결과**: PASS

---

## 빌드 검증

| 항목 | 결과 | 비고 |
|------|------|------|
| `npm run build` | PASS | 16 page(s) built, `/resume/index.html` 포함. 경고 1건(vite 미사용 import)은 기존부터 존재하며 에러 아님 |
| `npx tsc --noEmit` | PASS | 타입 오류 없음 |

---

## 수용 기준 체크리스트

| ID | 수용 기준 | 결과 | 확인 방법 |
|----|-----------|------|-----------|
| AC-1 | `npm run build`가 오류 없이 성공한다 | PASS | 빌드 로그: `16 page(s) built in 3.28s`, `/resume/index.html` 생성 확인 |
| AC-2 | `npx tsc --noEmit`이 통과한다 | PASS | 출력 없음 (오류 0건) |
| AC-3 | `/resume` 페이지가 존재하며 렌더링된다 | PASS | `GET /resume/` → HTTP 200. `<h1>김태수</h1>` 등 콘텐츠 정상 렌더링 확인 |
| AC-4 | 페이지에 "김태수" 텍스트가 존재한다 | PASS | `curl http://localhost:4321/resume/` 응답에 "김태수" 3회 포함 (h1, meta description, title) |
| AC-5 | "Professional Summary" 또는 "요약" 섹션이 존재한다 | PASS | `<h2>Professional Summary</h2>` 섹션 렌더링 확인 |
| AC-6 | 경력 섹션에 "비트망고" 텍스트가 존재한다 | PASS | `<h3>비트망고 (BitMango)</h3>` 포함 확인 |
| AC-7 | 기술 스택 섹션에 "StarRocks", "Apache Doris" 뱃지가 존재한다 | PASS | StarRocks 2회, Apache Doris 2회 확인. `color-tag-bg`/`color-tag-text` CSS 변수 인라인 뱃지 스타일 58회 적용 확인 |
| AC-8 | 헤더 nav의 "이력서" 링크가 `/resume/`로 연결된다 | PASS | `<a href="/resume/" ...>이력서</a>` 확인. 현재 페이지(`/resume/`)에서 액티브 클래스(`text-[var(--color-accent)]`) 자동 적용 확인 |
| AC-9 | 기존 라우트(`/`, `/blog/`) 정상 동작 (regression) | PASS | `/` HTTP 200, `/blog/` HTTP 200 확인 |

---

## 회귀(Regression) 검증

| 라우트 | 결과 | 비고 |
|--------|------|------|
| `/` (홈) | PASS | HTTP 200 |
| `/blog/` (목록) | PASS | HTTP 200 |
| `/tags/` (태그 인덱스) | PASS | HTTP 200 |
| `/rss.xml` (RSS 피드) | PASS | HTTP 200 |

---

## 코드 리뷰

- **스펙 범위 준수**: PASS — `src/pages/resume.astro` 신규 생성, `src/config/site.ts`의 nav 항목 추가 외 변경 없음. 스펙에 명시된 변경 대상(`src/pages/resume.astro`) 외 `site.ts` nav 수정은 AC-8을 충족하기 위해 필수적인 최소 변경임
- **보안**: PASS — 환경변수 노출 없음. XSS 가능성 없음 (정적 문자열만 사용)
- **기존 패턴 일관성**: PASS — `BaseLayout` 사용, CSS 변수(`--color-*`) 및 TailwindCSS만 사용, 별도 CSS 파일 추가 없음. 타임라인 스타일(왼쪽 보더 + 점) 스펙대로 구현. `TagBadge` 대신 인라인 `<span>` 뱃지 사용(스펙 지침 준수)

---

## 다음 사이클 제안

이번 작업 중 발견한 개선 아이디어 (기획 에이전트에게 전달):

1. PDF 다운로드 버튼 — 스펙에서 명시적으로 제외했지만 이력서 페이지의 핵심 UX. `@media print` 스타일과 함께 구현 가능
2. 이력서 콘텐츠 데이터 분리 — 현재 마크업에 하드코딩된 이력 내용을 `src/data/resume.ts` 또는 Notion 페이지로 분리하면 콘텐츠 관리가 용이해짐
3. 인쇄 전용 스타일 — 브라우저 인쇄 시 헤더/푸터 숨김, 컬러 배경 제거 등 `@media print` 최적화
4. Open Graph 이미지 — 현재 `/resume/` 페이지는 기본 OG 이미지(`og-default.png`)를 사용 중. 이력서 전용 OG 이미지 생성 고려
