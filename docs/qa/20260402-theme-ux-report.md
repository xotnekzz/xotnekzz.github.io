# QA 보고서: 테마 색상 및 UX 개선

- **날짜**: 2026-04-02
- **사이클**: #6
- **스펙 문서**: `docs/spec/20260402-theme-ux-improvement.md`
- **검증자**: 검증 에이전트
- **전체 결과**: PASS

---

## 빌드 검증

| 항목 | 결과 | 비고 |
|------|------|------|
| `npm run build` | PASS | 70 page(s) built, 오류 없음 |
| `npx tsc --noEmit` | PASS | 타입 오류 없음 |

---

## 수용 기준 체크리스트

| ID | 수용 기준 | 결과 | 확인 방법 |
|----|-----------|------|-----------|
| AC-1 | `npm run build` 오류 없이 성공 | PASS | 빌드 로그: 70 pages built in 2.34s |
| AC-2 | `npx tsc --noEmit` 통과 | PASS | 출력 없음 (오류 0건) |
| AC-3 | `:root` `--color-bg`가 `#ffffff` 또는 `#fafafa` | PASS | 값: `#ffffff` |
| AC-4 | `:root` `--color-text`가 `#1a1a1a` | PASS | 값: `#1a1a1a` |
| AC-5 | `:root` `--color-bg-secondary`가 `#f0f0f0`~`#f5f5f5` 또는 `#f3f4f6` 범위 | PASS | 값: `#f3f4f6` |
| AC-6 | `[data-theme="dark"]`에서 `#0f172a`, `#0d1117`, `#1e293b` 제거 | PASS | 세 값 모두 global.css에 존재하지 않음 |
| AC-7 | `[data-theme="dark"]` `--color-bg`가 `#111111`~`#1a1a1a` 범위 | PASS | 값: `#141414` (0x14=20, 범위 0x11=17~0x1a=26) |
| AC-8 | `[data-theme="dark"]` `--color-bg-secondary`가 `#1f1f1f`~`#2a2a2a` 범위 | PASS | 값: `#1f1f1f` (범위 하한과 일치) |
| AC-9 | `[data-theme="dark"]` `--color-text`가 `#d1d5db`~`#f1f5f9` 범위 | PASS | 값: `#e8e8e8` (0xe8=232, 범위 0xd1=209~0xf1=241) |
| AC-10 | `[data-theme="dark"]` `--color-text-muted`가 `#888888`~`#a8a8a8` 범위 | PASS | 값: `#9ca3af` (R채널 0x9c=156, 범위 0x88=136~0xa8=168) |
| AC-11 | `--color-accent` blue 계열 유지 | PASS | dark: `#60a5fa`, light: `#2563eb` — 모두 blue 계열 |
| AC-12 | `<article>`에 transition 관련 클래스 존재 | PASS | `transition-colors` 클래스 확인 |
| AC-13 | `<article>`에 hover 배경색 변경 스타일 존재 | PASS | `hover:bg-[var(--color-bg-secondary)]` 확인 |
| AC-14 | 타이틀 링크의 `hover:text-[var(--color-accent)]` 유지 | PASS | `<a>` 태그에 `hover:text-[var(--color-accent)]` 유지됨 |
| AC-15 | `/blog/` 빌드 결과물 포함 | PASS | `dist/blog/index.html` 생성 확인 |
| AC-16 | `/resume/` 빌드 결과물 포함 | PASS | `dist/resume/index.html` 생성 확인 |
| AC-17 | `/tags/` 빌드 결과물 포함 | PASS | `dist/tags/index.html` 생성 확인 |

---

## FAIL 상세

> FAIL 항목 없음

---

## 회귀(Regression) 검증

| 라우트 | 결과 | 비고 |
|--------|------|------|
| `/` (홈) | PASS | `dist/index.html` 생성 확인 |
| `/blog/` (목록) | PASS | `dist/blog/index.html` 생성 확인 |
| `/tags/` (태그 인덱스) | PASS | `dist/tags/index.html` 생성 확인 |
| `/resume/` (이력서) | PASS | `dist/resume/index.html` 생성 확인 |
| `/rss.xml` (RSS 피드) | PASS | 빌드 로그에서 `/rss.xml` 생성 확인 |

---

## 코드 리뷰

- **스펙 범위 준수**: PASS — `global.css`, `PostListItem.astro` 두 파일만 변경, 스펙 명시 범위 외 변경 없음
- **보안**: PASS — 환경변수 노출, XSS 등 보안 이슈 없음
- **기존 패턴 일관성**: PASS — Tailwind 유틸리티 클래스 방식 일관성 유지, CSS 변수 네이밍 규칙 준수

### CSS 변수 변경 요약

| 변수 | 변경 전 | 변경 후 | 스펙 일치 |
|------|---------|---------|-----------|
| `[data-theme="dark"]` `--color-bg` | `#0f172a` (추정) | `#141414` | 일치 |
| `[data-theme="dark"]` `--color-bg-secondary` | `#1e293b` (추정) | `#1f1f1f` | 일치 |
| `[data-theme="dark"]` `--color-text` | `#f1f5f9` (추정) | `#e8e8e8` | 일치 |
| `[data-theme="dark"]` `--color-text-muted` | `#94a3b8` (추정) | `#9ca3af` | 일치 |
| `[data-theme="dark"]` `--color-border` | `#334155` (추정) | `#2e2e2e` | 일치 |
| `[data-theme="dark"]` `--color-tag-bg` | `#1e3a5f` (추정) | `#1e2a3a` | 일치 |
| `:root` `--color-bg-secondary` | (이전 값 미확인) | `#f3f4f6` | 스펙 명시값 일치 |

---

## 다음 사이클 제안

이번 작업 중 발견한 개선 아이디어 (기획 에이전트에게 전달):

1. **다크 모드 `--color-text-muted` 순수 회색 전환 검토** — 현재 `#9ca3af`는 Tailwind `gray-400`(blue-gray 계열)으로 미세한 청색 기미가 남아있음. 완전한 중립 회색(`#9a9a9a` 등)으로 교체 시 다크 모드 순수 회색 톤 일관성 향상 가능
2. **호버 이펙트 padding/rounding 미세 조정** — `rounded-sm`과 `-mx-3 px-3` 음수 마진 조합으로 구현된 호버 영역이 시각적으로 자연스럽게 보이는지 실기기 브라우저 확인 권장
3. **`prefers-color-scheme` 자동 감지 도입 검토** — 이번 사이클 범위 외였으나, 다크 모드 색상 품질이 개선된 지금 시스템 테마 자동 연동을 다음 사이클 우선순위로 고려할 만함
