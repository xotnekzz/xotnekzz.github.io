# 스펙: 포트폴리오 탭 네비게이션 레이아웃 개선

**작성자:** 기획 에이전트  
**작성일:** 2026-04-06  
**버전:** v1.0  
**상태:** 기획 완료  
**이전 스펙:** `docs/spec/20260402-portfolio-display.md` (PASS - 2026-04-06)

---

## 1. 목표 및 배경

### 1.1 목표
포트폴리오 페이지의 섹션 기반 레이아웃을 **탭 기반 네비게이션**으로 전환하여, 사용자 경험을 개선하고 페이지 구조를 간소화합니다.

### 1.2 현재 상황

**현재 레이아웃 (섹션 기반):**
```
┌─ Portfolio (메인 제목)
│
├─ ┌─ AIEnginerring (카테고리 헤더)
│  ├─ 프로젝트 1
│  ├─ 프로젝트 2
│  └─ 프로젝트 3
│
├─ ┌─ AnalyticsEnginering
│  └─ 프로젝트 1
│
├─ ┌─ DataEngineering
│  ├─ 프로젝트 1
│  ├─ 프로젝트 2
│  ├─ 프로젝트 3
│  ├─ 프로젝트 4
│  └─ 프로젝트 5
│
└─ ┌─ Governance
   └─ 프로젝트 1
```

**문제점:**
- 모든 카테고리가 한 페이지에 표시되어 **스크롤 양이 많음** (10개 항목 전체 로드)
- 특정 카테고리에만 집중하기 어려움 (시각적 분산)
- 카테고리 간 전환 시 페이지 스크롤 필요

### 1.3 배경

사용자가 특정 카테고리의 포트폴리오를 **빠르게 확인**하고, 카테고리 간 **직관적으로 전환**할 수 있도록 개선하기 위해, 탭 네비게이션 패턴을 도입합니다. 이는 현대적 웹 UX 패턴으로, 대시보드, 관리 페이지 등에서 널리 사용되는 검증된 디자인입니다.

---

## 2. 요구사항 분석

### 2.1 탭 네비게이션 기능 요구사항

#### 2.1.1 탭 목록 (카테고리)
```
알파벳 순 정렬:
1. AIEnginerring (3개 항목)
2. AnalyticsEnginering (1개 항목)
3. DataEngineering (5개 항목)
4. Governance (1개 항목)
```

#### 2.1.2 탭 상호작용
| 항목 | 요구사항 |
|------|---------|
| **초기 상태** | 첫 번째 탭(AIEnginerring) 기본 선택 |
| **탭 클릭** | 클릭한 탭 활성화, 다른 탭 비활성화 |
| **활성 탭 표시** | 스타일 변경으로 강조 (색상, 밑줄, 배경색 등) |
| **콘텐츠 전환** | 탭 전환 시 해당 카테고리 프로젝트만 표시 |
| **페이지 스크롤** | 탭 네비게이션은 고정 위치 (sticky) 고려 |

#### 2.1.3 스타일 요구사항
- **기존 CSS 변수 활용:** `--color-*` 테마 호환성 유지
- **활성 탭:** 명확한 시각적 구분 (예: 밑줄, 색상 강조)
- **비활성 탭:** 희미한 색상 (muted)
- **호버 효과:** 마우스 호버 시 강조 (커서 포인터 표시)

#### 2.1.4 반응형 디자인
- **데스크톱 (> 768px):** 탭 네비게이션 수평 정렬
- **모바일 (< 768px):** 탭이 스크롤 가능한 수평 레이아웃 또는 드롭다운 선택 (선택 사항)

### 2.2 클라이언트 사이드 상호작용

#### 2.2.1 기술 요구사항
- **상태 관리:** 선택한 탭 추적 (JavaScript 또는 Astro Island 사용)
- **동작:** 탭 클릭 → 활성 탭 변경 → 콘텐츠 렌더링
- **성능:** 클라이언트 사이드 렌더링 (DOM 조작)으로 빠른 전환

#### 2.2.1 Astro Island 고려사항
Astro 6에서는 클라이언트 상호작용이 필요한 경우 **hydration** 방식 선택:
- **client:load:** 페이지 로드 시 즉시 hydrate (추천)
- **client:idle:** 유휴 시간에 hydrate (성능 중시)
- **client:visible:** 요소 보임 시 hydrate (지연 로딩)

**선택 이유:** `client:load`가 적절 (사용자가 즉시 탭 전환을 기대함)

### 2.3 접근성 요구사항

#### 2.3.1 ARIA 속성
```html
<div role="tablist" aria-label="카테고리 필터">
  <button role="tab" 
          aria-selected="true"
          aria-controls="panel-1"
          id="tab-1">
    AIEnginerring
  </button>
</div>

<div role="tabpanel" 
     id="panel-1" 
     aria-labelledby="tab-1">
  <!-- 프로젝트 콘텐츠 -->
</div>
```

#### 2.3.2 키보드 네비게이션
- Tab 키: 탭 간 이동
- Enter/Space: 탭 활성화
- Arrow Left/Right: 인접 탭으로 이동 (선택 사항)

---

## 3. 구현 계획

### 3.1 변경 대상 파일

#### 3.1.1 `src/pages/portfolio.astro` (필수)
**목표:** 탭 네비게이션 UI 추가 및 클라이언트 상호작용 로직 구현

**변경 내용:**
1. 탭 네비게이션 HTML 마크업 추가
   - `role="tablist"` 및 `role="tab"` 적용
   - 알파벳 순 정렬된 탭 생성
   
2. 프로젝트 콘텐츠 패널화
   - `role="tabpanel"` 적용
   - 각 탭별 프로젝트 콘텐츠 마크업
   
3. 클라이언트 사이드 로직 (Astro Island)
   - 탭 활성화/비활성화 토글
   - 패널 표시/숨김 제어
   - 초기 상태: 첫 번째 탭 활성

**코드 구조 (Astro Island):**
```astro
---
import BaseLayout from '../layouts/BaseLayout.astro';
import PortfolioTabs from '../components/PortfolioTabs.astro';

// 포트폴리오 데이터 로드 (기존 로직 유지)
const portfolioFiles = import.meta.glob('../content/portfolio/*/*.md', { eager: true });
const projects = [...]; // 기존 정렬 로직
const grouped = groupByCategory(projects);
const sortedCategories = Object.keys(grouped).sort();
---

<BaseLayout>
  <section>
    <h1>Portfolio</h1>
    <!-- 탭 네비게이션 (클라이언트 island) -->
    <PortfolioTabs 
      categories={sortedCategories}
      data={grouped}
    />
  </section>
</BaseLayout>
```

#### 3.1.2 `src/components/PortfolioTabs.astro` (신규, 필수)
**목표:** 탭 네비게이션 및 콘텐츠 패널 컴포넌트

**기능:**
- Props로 받은 카테고리 목록 및 데이터 렌더링
- Astro Island로 클라이언트 상호작용 처리
- 활성 탭 스타일 적용
- 각 패널의 프로젝트 콘텐츠 렌더링

**예상 구조:**
```astro
---
// Props
export interface Props {
  categories: string[];
  data: Record<string, Portfolio[]>;
}

const { categories, data } = Astro.props;
---

<div class="portfolio-tabs-wrapper">
  <!-- 탭 네비게이션 (static) -->
  <div class="tabs-nav">
    {categories.map((cat) => (
      <button data-tab={cat}>
        {cat}
      </button>
    ))}
  </div>
  
  <!-- 콘텐츠 패널 (with island) -->
  <PortfolioTabContent 
    client:load
    categories={categories}
    data={data}
  />
</div>
```

#### 3.1.3 `src/components/PortfolioTabContent.tsx` (신규, 선택)
**목표:** 클라이언트 사이드 상호작용 로직 (필요시 JSX/TSX 사용)

**기능:**
- React/JSX를 사용하여 탭 상태 관리 (useState)
- 탭 클릭 핸들러
- 활성 탭 스타일 바인딩
- 패널 조건부 렌더링

**선택 이유:** 
- 상태 관리가 간단한 경우 vanilla JS 가능
- 복잡한 경우 React 컴포넌트로 분리

#### 3.1.4 스타일시트 (CSS)
**변경 위치:** `src/styles/global.css` (추가) 또는 `src/components/PortfolioTabs.astro` (scoped)

**스타일 요구사항:**
```css
/* 탭 네비게이션 */
.tabs-nav {
  display: flex;
  gap: 1rem;
  border-bottom: 1px solid var(--color-border);
}

.tab-button {
  padding: 0.75rem 1rem;
  background: transparent;
  border: none;
  cursor: pointer;
  color: var(--color-text-muted);
  transition: color 0.2s, border-color 0.2s;
  border-bottom: 2px solid transparent;
}

.tab-button:hover {
  color: var(--color-text);
}

.tab-button.active {
  color: var(--color-accent);
  border-bottom-color: var(--color-accent);
  font-weight: 500;
}

/* 패널 */
.tab-panel {
  display: none;
}

.tab-panel.active {
  display: block;
}
```

### 3.2 기존 코드와의 호환성

#### 3.2.1 포트폴리오 데이터 로직 (변경 없음)
```typescript
// lib/portfolio.ts 유지
- extractCategory()
- sortByDateDesc()
- groupByCategory()
- formatDateKorean()
```

#### 3.2.2 Portfolio 타입 (변경 없음)
```typescript
// lib/types.ts 유지
interface Portfolio {
  title: string;
  description: string;
  date: string;
  tags: string[];
  featured?: boolean;
  category?: string;
}
```

#### 3.2.3 스타일 변수 (재사용)
```css
/* global.css에서 기존 정의 */
--color-text
--color-text-muted
--color-accent
--color-accent-hover
--color-border
--color-tag-bg
--color-tag-text
```

---

## 4. 기술 스택 및 의존성

### 4.1 사용할 기술
- **Astro 6:** 정적 사이트 생성 + Island Architecture
- **TypeScript:** 타입 안정성
- **CSS:** 기존 변수 시스템 활용
- **Vanilla JavaScript 또는 React:** 클라이언트 상호작용 (필요시)

### 4.2 새 의존성
- **없음** (기존 Astro + TypeScript 스택 활용)

### 4.3 호환성
- **Node.js:** 18.x 이상 (기존 유지)
- **Astro:** 6.x
- **브라우저:** ES2020 이상 (JavaScript 지원)

---

## 5. 수용 기준 (Acceptance Criteria)

### 5.1 기능 수용 기준

| # | 항목 | 검증 방법 | 예상 결과 |
|---|------|---------|---------|
| 1 | 빌드 성공 | `npm run build` 실행 | 빌드 완료, 오류 없음 |
| 2 | 탭 네비게이션 렌더링 | `/portfolio` 접속 | 4개 탭 모두 표시 |
| 3 | 초기 탭 선택 | 페이지 로드 완료 | 첫 번째 탭(AIEnginerring) 활성 표시 |
| 4 | 탭 클릭 상호작용 | 각 탭 클릭 | 클릭한 탭 활성화, 콘텐츠 변경 |
| 5 | 활성 탭 강조 | 시각적 확인 | 활성 탭만 강조 스타일 적용 |
| 6 | 패널 콘텐츠 정확성 | 각 탭 콘텐츠 확인 | 해당 카테고리의 프로젝트만 표시 |
| 7 | 비활성 탭 숨김 | 패널 표시/숨김 확인 | 활성 탭만 보임, 다른 탭 숨김 |
| 8 | 정렬 순서 유지 | 프로젝트 순서 확인 | featured 우선 + 날짜 내림차순 유지 |
| 9 | 반응형 레이아웃 | 모바일 (375px+) | 탭 네비게이션 깨지지 않음 |
| 10 | CSS 변수 호환성 | 테마 전환 | 다크/라이트 모드 정상 적용 |
| 11 | 접근성 (ARIA) | 스크린 리더 또는 HTML 검사 | role, aria-* 속성 올바름 |
| 12 | TypeScript 타입 커버리지 | `npx tsc --noEmit` | 타입 오류 0개 |

### 5.2 성능 수용 기준
- **페이지 로드 시간:** 1초 이내 (개발 서버 기준)
- **탭 전환 시간:** 100ms 이내 (클라이언트 사이드 전환)
- **번들 크기 증가:** 20KB 미만 (Gzip) — 클라이언트 로직 + 컴포넌트

### 5.3 코드 품질 기준
- **TypeScript 타입 커버리지:** 100%
- **ESLint 경고:** 0개
- **Astro 빌드 경고:** 0개

---

## 6. 테스트 시나리오

### 6.1 기능 테스트 (Happy Path)

#### TC-1: 초기 로드 및 기본 탭 활성
```
Given: /portfolio 페이지 방문
When:  페이지 로드 완료
Then:  - 4개 탭 모두 렌더링됨 (AIEnginerring, AnalyticsEnginering, DataEngineering, Governance)
       - AIEnginerring 탭이 활성 상태 (강조 스타일 적용)
       - AIEnginerring 카테고리의 3개 프로젝트 표시
       - 다른 카테고리 프로젝트 숨김
```

#### TC-2: 탭 전환
```
Given: AIEnginerring 탭이 활성 상태
When:  DataEngineering 탭 클릭
Then:  - DataEngineering 탭 활성 상태로 변경
       - DataEngineering 강조 스타일 적용
       - DataEngineering의 5개 프로젝트 표시
       - AIEnginerring 프로젝트 숨김
       - 스크롤 위치 유지 (또는 탭 위치로 스크롤)
```

#### TC-3: 모든 탭 확인
```
Given: /portfolio 페이지
When:  각 탭 순서대로 클릭
Then:  - AnalyticsEnginering: 1개 프로젝트
       - DataEngineering: 5개 프로젝트
       - Governance: 1개 프로젝트
       - 각 탭의 프로젝트 정렬: featured 우선 + 날짜 내림차순
```

#### TC-4: 호버 효과
```
Given: /portfolio 페이지
When:  비활성 탭에 마우스 호버
Then:  - 호버 상태 시각 피드백 (색상 변경, 커서 포인터)
       - 클릭 가능함을 나타냄
```

### 6.2 엣지 케이스 (Edge Cases)

#### TC-5: 빠른 탭 전환
```
Given: AIEnginerring 탭 활성
When:  빠르게 여러 탭 클릭 (DataEngineering → AnalyticsEnginering → Governance)
Then:  - 마지막 클릭한 탭(Governance)이 최종 활성
       - 콘텐츠 깜빡임 없음
       - UI 상태 일관성 유지
```

#### TC-6: 키보드 탭 키 네비게이션
```
Given: 탭 네비게이션 포커스 상태
When:  Tab 키 누름
Then:  - 다음 탭으로 포커스 이동
       - 포커스 표시 명확 (아웃라인 등)
```

#### TC-7: 비활성 탭 콘텐츠 숨김 확인
```
Given: AnalyticsEnginering 탭 활성
When:  HTML 소스 검사
Then:  - 활성 탭 패널만 display: block (또는 visible)
       - 비활성 탭 패널 display: none 또는 hidden
       - 성능: 비활성 콘텐츠는 DOM에 있지만 렌더링 안 됨
```

### 6.3 회귀 테스트

#### TC-8: 기존 프로젝트 데이터 유지
```
Given: 탭 네비게이션 추가 후
When:  각 탭의 프로젝트 확인
Then:  - featured 상태 유지
       - 메타데이터(제목, 설명, 날짜, 태그) 정확
       - 정렬 순서 유지 (featured → 날짜 내림차순)
```

#### TC-9: CSS 변수 호환성
```
Given: 다크 모드 & 라이트 모드
When:  테마 토글 (`ThemeToggle` 컴포넌트)
Then:  - 탭 네비게이션 색상 올바르게 변경
       - --color-text, --color-accent 등 적용
       - 색상 대비 충분 (접근성)
```

#### TC-10: 다른 페이지 영향 없음
```
Given: 포트폴리오 탭 네비게이션 추가 후
When:  다른 페이지 방문 (/, /blog, /resume, /tags)
Then:  - 모든 페이지 정상 작동
       - 레이아웃/스타일 변화 없음
       - 포트폴리오 JavaScript 간섭 없음
```

---

## 7. 이번 사이클에서 하지 않는 것 (Out of Scope)

### 7.1 제외 기능
- [x] **URL 쿼리 파라미터 연동** (`?tab=DataEngineering`) — 향후 사이클
- [x] **탭 선택 상태 localStorage 저장** — 향후 사이클
- [x] **드롭다운 선택 (모바일)** — 수평 스크롤 대신 고정 탭 사용
- [x] **탭 애니메이션** (transition, fade) — 선택 사항 (간단한 show/hide)
- [x] **포트폴리오 검색/필터** — 향후 사이클
- [x] **포트폴리오 상세 페이지** (`/portfolio/[id]`) — 향후 사이클

### 7.2 의도적 제한사항
- **서버 사이드 렌더링:** 탭 상태는 클라이언트 사이드에서만 관리 (Astro Island)
- **URL 변경:** 탭 전환 시 URL 변경 없음 (SPA가 아니므로)
- **뒤로 가기:** 탭 선택 상태는 브라우저 히스토리에 저장 안 함

---

## 8. 개발 체크리스트

### Phase 1: 계획 & 설계
- [x] 현재 포트폴리오 페이지 구조 파악
- [x] 탭 네비게이션 요구사항 정의
- [x] 기술 스택 검토 (Astro Island 활용)
- [x] 이 스펙 문서 작성

### Phase 2: 컴포넌트 개발 (개발 에이전트)
- [ ] `src/components/PortfolioTabs.astro` 생성
  - [ ] 탭 네비게이션 마크업 (role, aria-*)
  - [ ] 데이터 Props 정의
  - [ ] 스타일링 (CSS)
  
- [ ] 클라이언트 상호작용 구현
  - [ ] 탭 활성화 로직 (Vanilla JS 또는 React)
  - [ ] 패널 show/hide 제어
  - [ ] 초기 상태 설정

### Phase 3: 페이지 통합
- [ ] `src/pages/portfolio.astro` 업데이트
  - [ ] 기존 섹션 레이아웃 제거
  - [ ] `<PortfolioTabs>` 컴포넌트 임포트 및 사용
  - [ ] Props 전달 (categories, data)

### Phase 4: 스타일링 & 접근성
- [ ] Tailwind 클래스 및 CSS 변수 적용
- [ ] ARIA 속성 검증 (role, aria-selected, aria-controls)
- [ ] 키보드 네비게이션 지원 (Tab, Enter)
- [ ] 다크/라이트 모드 테스트

### Phase 5: 테스트 & 검증
- [ ] 로컬 개발 서버에서 기능 테스트 (npm run dev)
- [ ] 모든 TC (테스트 시나리오) 검증
- [ ] 빌드 성공 확인 (npm run build)
- [ ] 회귀 테스트 (기존 페이지 영향 없음)

### Phase 6: 최종 검증 (QA Agent)
- [ ] 수용 기준 12개 항목 검증
- [ ] 성능 기준 확인
- [ ] 코드 품질 검증
- [ ] 배포 준비

---

## 9. 예상 산출물

### 9.1 코드 변경사항
- `src/pages/portfolio.astro` (수정)
- `src/components/PortfolioTabs.astro` (신규)
- `src/components/PortfolioTabContent.tsx` (신규, 선택)
- `src/styles/global.css` (추가, 선택) 또는 scoped CSS

### 9.2 문서
- 이 스펙 문서 (완료)
- 개발 에이전트를 위한 구현 가이드 (별도 제공)
- QA 검증 보고서 (개발 완료 후 생성)

### 9.3 배포
- GitHub Pages 자동 배포 (CI/CD)
- 변경사항 없음 (기존 배포 프로세스 유지)

---

## 10. 참고 자료

### 10.1 Astro & Island Architecture
- **Astro Islands 공식 문서:** https://docs.astro.build/en/concepts/islands/
- **Astro Framework Integration:** React, Vue, Svelte 등 프레임워크 컴포넌트 활용

### 10.2 접근성 (WCAG 2.1)
- **ARIA 탭 패턴:** https://www.w3.org/WAI/ARIA/apg/patterns/tabs/
- **키보드 네비게이션:** https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/

### 10.3 프로젝트 리소스
- **프로젝트 스택:** `docs/stack.md`
- **이전 포트폴리오 스펙:** `docs/spec/20260402-portfolio-display.md`
- **포트폴리오 QA 보고서:** `docs/qa/20260406-portfolio-display-report.md`
- **포트폴리오 라이브러리:** `src/lib/portfolio.ts`

---

## 11. 위험 관리 (Risk Management)

### 11.1 기술적 위험

| 위험 | 확률 | 영향 | 완화 방안 |
|------|------|------|---------|
| Astro Island hydration 실패 | 낮음 | 중간 | `client:load` 사용으로 즉시 hydrate |
| JavaScript 비활성 사용자 | 낮음 | 중간 | 폴백: 섹션 레이아웃 유지 (선택 사항) |
| 모바일 탭 오버플로우 | 중간 | 낮음 | 수평 스크롤 또는 드롭다운 고려 |
| 성능 저하 (클라이언트 JS) | 낮음 | 낮음 | Vanilla JS 사용 (프레임워크 최소화) |

### 11.2 UX 위험

| 위험 | 확률 | 영향 | 완화 방안 |
|------|-----|------|---------|
| 탭 선택 상태 명확하지 않음 | 중간 | 중간 | 강한 시각적 차별화 (색상 + 밑줄) |
| 모바일에서 탭 가독성 낮음 | 중간 | 낮음 | 적절한 padding/font-size |
| 사용자가 이전 섹션 레이아웃 선호 | 낮음 | 낮음 | 사용자 피드백 수집 후 개선 |

---

## 12. 승인 및 진행

**기획 완료:** 2026-04-06  
**다음 단계:** 개발 에이전트 할당 및 구현 시작

**스펙 상태:** ✅ READY FOR DEVELOPMENT

---

*기획 에이전트 작성 (Planner Agent)*
