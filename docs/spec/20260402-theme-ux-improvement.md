# 스펙: 테마 색상 및 UX 개선

- **날짜**: 2026-04-02
- **사이클**: #6
- **작성자**: 기획 에이전트

---

## 목표

현재 다크 모드의 짙은 남색(네이비) 계열 배경을 가독성이 높은 중립 회색 계열로 변경하고,
포스트 목록 리스트 아이템에 호버 이펙트를 추가하여 인터랙션 피드백을 개선한다.
전반적인 UI/UX 품질을 높여 블로그 방문자의 읽기 경험을 향상시킨다.

**배경:** 현재 `[data-theme="dark"]`의 배경색(`#0f172a`, `#1e293b`)이 Tailwind의 `slate` 계열(남색 기미)로
설정되어 있어 장시간 독서 시 눈의 피로를 유발할 수 있다는 피드백에 기반한다.
또한 `PostListItem`의 호버 상태가 타이틀 링크 색상 변경(`hover:text-[var(--color-accent)]`)에만 국한되어
아이템 영역 전체에 대한 시각적 피드백이 부족하다.

---

## 변경 대상 파일

```
src/styles/global.css                  — CSS 변수 값 수정 (다크 모드 bg/text 네이비 → 중립 회색, 라이트 모드 미세 조정)
src/components/PostListItem.astro      — article 요소에 호버 이펙트 CSS 클래스 추가
```

---

## 수용 기준 (Acceptance Criteria)

### 빌드 / 타입

- [ ] **AC-1**: `npm run build`가 오류 없이 성공한다
- [ ] **AC-2**: `npx tsc --noEmit`이 통과한다

### 테마 색상 — 라이트 모드

- [ ] **AC-3**: `:root`의 `--color-bg` 값이 `#ffffff` 또는 `#fafafa` 이다
- [ ] **AC-4**: `:root`의 `--color-text` 값이 `#1a1a1a` 이다
- [ ] **AC-5**: `:root`의 `--color-bg-secondary` 값이 `#f0f0f0` ~ `#f5f5f5` 또는 `#f3f4f6` 범위의 밝은 회색 계열이다

### 테마 색상 — 다크 모드 (네이비 제거)

- [ ] **AC-6**: `[data-theme="dark"]`의 `--color-bg` 값에서 `#0f172a`, `#0d1117`, `#1e293b` 값이 모두 제거된다
- [ ] **AC-7**: `[data-theme="dark"]`의 `--color-bg` 값이 `#111111` ~ `#1a1a1a` 범위 내의 순수 회색 계열이다
- [ ] **AC-8**: `[data-theme="dark"]`의 `--color-bg-secondary` 값이 `#1f1f1f` ~ `#2a2a2a` 범위 내의 값이다
- [ ] **AC-9**: `[data-theme="dark"]`의 `--color-text` 값이 `#d1d5db` ~ `#f1f5f9` 범위의 밝은 회색이다
- [ ] **AC-10**: `[data-theme="dark"]`의 `--color-text-muted` 값이 `#888888` ~ `#a8a8a8` 범위의 중간 회색이다

### accent 색상

- [ ] **AC-11**: `--color-accent` 값이 변경되지 않거나, 변경된 경우 blue 계열을 유지한다

### 호버 이펙트 — PostListItem

- [ ] **AC-12**: `<article>` 요소에 `transition` 관련 클래스 또는 속성이 추가된다
- [ ] **AC-13**: `<article>` 요소에 호버 시 배경색이 변경되는 스타일이 존재한다 (`hover:bg-[var(--color-bg-secondary)]` 또는 동등)
- [ ] **AC-14**: 호버 이펙트 적용 후에도 타이틀 링크의 `hover:text-[var(--color-accent)]` 색상 변경이 유지된다

### 회귀 (Regression)

- [ ] **AC-15**: `/blog/` 페이지 정상 로드
- [ ] **AC-16**: `/resume/` 페이지 정상 로드
- [ ] **AC-17**: `/tags/` 페이지 정상 로드

---

## 구현 상세 가이드

### global.css 변경 내용

**`[data-theme="dark"]` — 변경 대상 변수:**

| 변수 | 현재 값 | 변경 값 |
|------|---------|---------|
| `--color-bg` | `#0f172a` | `#141414` |
| `--color-bg-secondary` | `#1e293b` | `#1f1f1f` |
| `--color-text` | `#f1f5f9` | `#e8e8e8` |
| `--color-text-muted` | `#94a3b8` | `#9ca3af` |
| `--color-border` | `#334155` | `#2e2e2e` |
| `--color-tag-bg` | `#1e3a5f` | `#1e2a3a` |

accent 계열(`--color-accent`, `--color-accent-hover`, 등)은 변경하지 않는다.

라이트 모드는 `--color-bg-secondary`만 `#f3f4f6`으로 미세 조정한다.

### PostListItem.astro 변경 내용

`<article>` 요소에 호버 배경 + 트랜지션 클래스 추가:

```astro
<article
  class="post-item py-6 border-b rounded-sm px-3 -mx-3 transition-colors hover:bg-[var(--color-bg-secondary)]"
  style="border-color: var(--color-border);"
  ...
>
```

---

## 테스트 시나리오

1. **다크 모드 색상**: 배경이 짙은 회색 계열로 표시됨 — 파란 기미 없음
2. **호버 이펙트**: `/blog/`에서 포스트 아이템에 마우스 올리면 배경색이 부드럽게 전환됨
3. **필터 동작**: 카테고리/검색 필터가 색상 변경 후에도 정상 동작

---

## 이번 사이클에서 하지 않는 것

- OS 테마 자동 감지 (`prefers-color-scheme`) 변경
- 폰트 패밀리, 사이즈, 줄간격 등 타이포그래피 변경
- 레이아웃 구조 변경 (`BaseLayout.astro`, `Header.astro` 등)
- 필터/검색 기능 로직 변경
- PostListItem 외 다른 컴포넌트에 호버 이펙트 적용
- keyframes/transform 기반 애니메이션 추가
