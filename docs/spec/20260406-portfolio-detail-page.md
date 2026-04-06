# 포트폴리오 상세 페이지 기능 스펙 (20260406)

**작성자:** 기획 에이전트  
**작성일:** 2026-04-06  
**상태:** 검토 대기

---

## 1. 목표 및 배경

### 1.1 목표

포트폴리오 항목을 **마크다운 전체 콘텐츠로 렌더링하는 상세 페이지** 기능 추가

사용자가 포트폴리오 리스트에서 항목을 클릭하면 블로그 포스트처럼 전체 마크다운 본문, 메타데이터(제목, 날짜, 태그)를 포함한 상세 페이지로 이동할 수 있도록 한다.

### 1.2 배경

**현재 상황:**
- 포트폴리오 페이지(`/portfolio`)는 탭 기반 레이아웃으로 카테고리별 항목을 리스트 형태로만 표시
- 각 항목은 제목, 설명, 날짜, 태그만 표시됨
- 마크다운 파일에는 상세한 본문 콘텐츠가 있지만 렌더링되지 않음

**요구사항:**
- 포트폴리오 항목의 전체 마크다운 콘텐츠(기술 상세, 성과, 인사이트)를 읽을 수 있어야 함
- 포트폴리오를 보다 전문적이고 깊이 있게 표현
- 사용자 경험 향상 (포트폴리오 → 상세 페이지 클릭 흐름)

**유사 사례:** 블로그 포스트 상세 페이지 구현(`src/pages/blog/[...slug].astro`) 참고

---

## 2. 변경 대상 파일 후보

### 2.1 신규 파일

| 파일명 | 목적 |
|--------|------|
| `src/pages/portfolio/[category]/[slug].astro` | 포트폴리오 상세 페이지 (동적 라우팅) |
| `src/layouts/PortfolioDetailLayout.astro` | 포트폴리오 상세 페이지 레이아웃 |

### 2.2 수정 파일

| 파일명 | 변경 내용 |
|--------|----------|
| `src/components/PortfolioTabs.astro` | 각 항목에 상세 페이지 링크 추가 |
| `src/lib/portfolio.ts` | 슬러그 생성 유틸리티 함수 추가 |
| `src/lib/types.ts` | 필요시 타입 확장 |

---

## 3. 기술 설계

### 3.1 파일 구조 및 라우팅

**포트폴리오 마크다운 구조:**
```
src/content/portfolio/{category}/{filename}.md
  ├── 예: src/content/portfolio/AIEnginerring/사내 통합 AI 에이전트 플랫폼 구축.md
  ├── 예: src/content/portfolio/DataEngineering/ELT 파이프라인 설계 (PyAirbyte).md
```

**동적 라우팅 경로:**
```
/portfolio/{category}/{slug}/
  ├── 예: /portfolio/AIEnginerring/ai-agent-platform/
  ├── 예: /portfolio/DataEngineering/elt-pipeline-pyairbyte/
```

**슬러그 생성 규칙:**
- 마크다운 파일명에서 확장자 제거
- 한글/특수문자 → 영문 또는 제거
- 공백, 괄호 → 하이픈으로 변환
- 예: `사내 통합 AI 에이전트 플랫폼 구축.md` → `ai-agent-platform`
- 기존 블로그 포스트 슬러그 생성 방식 참고

### 3.2 페이지 레이아웃 구조

**포트폴리오 상세 페이지 (PortfolioDetailLayout.astro)**

```
┌─────────────────────────────────────────────────────────────────┐
│  태그 배지 (featured 뱃지 포함)                                  │
│  제목 (h1)                                                      │
│  설명 (한 줄)                                                    │
│  메타데이터 (날짜)                                               │
├─────────────────────────────────────────────────────────────────┤
│  마크다운 본문 콘텐츠                                            │
│  (제목, 문단, 이미지, 코드, 표 등)                             │
├─────────────────────────────────────────────────────────────────┤
│  ← 포트폴리오 목록으로 (네비게이션)                            │
└─────────────────────────────────────────────────────────────────┘
```

**스타일 재사용:**
- `PostLayout.astro`의 구조 및 스타일 대부분 재사용 가능
- `.notion-content` 스타일 클래스 적용 (마크다운 렌더링)
- 포트폴리오 특화 색상/강조 고려

### 3.3 동적 라우팅 구현

**파일: `src/pages/portfolio/[category]/[slug].astro`**

```typescript
export async function getStaticPaths() {
  // 1. portfolio 폴더의 모든 마크다운 파일 동적 로딩
  const files = import.meta.glob('../../content/portfolio/*/*.md', { eager: true });
  
  // 2. 각 파일에서 경로 매개변수 생성
  return Object.entries(files).map(([path, module]) => {
    const frontmatter = module.frontmatter || {};
    const category = extractCategory(path); // "AIEnginerring" 등
    const slug = generateSlug(module.frontmatter.title); // "ai-agent-platform"
    
    return {
      params: { category, slug },
      props: { portfolio: { ...frontmatter, category }, module }
    };
  });
}

const { portfolio } = Astro.props;
const { Content } = await render(portfolio);
```

**슬러그 생성 함수 (utils에 추가):**
```typescript
export function generateSlug(title: string): string {
  // 한글 → 로마자 변환 또는 제거
  // 공백, 괄호, 특수문자 → 하이픈
  // 예: "사내 통합 AI 에이전트 플랫폼 구축" → "ai-agent-platform"
}
```

### 3.4 포트폴리오 리스트 → 상세 페이지 링크

**PortfolioTabs.astro에 추가:**

```astro
{data[category].map((project) => (
  <a 
    href={`/portfolio/${project.category}/${generateSlug(project.title)}/`}
    class="project-link"
  >
    {/* 기존 프로젝트 카드 */}
  </a>
))}
```

---

## 4. 구현 고려사항

### 4.1 Frontmatter 메타데이터

포트폴리오 마크다운 파일의 frontmatter 구조 (기존):
```yaml
---
title: 사내 통합 AI 에이전트 플랫폼 구축
description: LibreChat + MCP + Milvus 기반 RAG 인프라...
date: 2025-04-01
tags:
  - LibreChat
  - MCP
featured: true
---
```

**검증 기준:**
- 모든 포트폴리오 항목에 `title`, `description`, `date` 필수
- `tags` 배열 (선택사항, 기본값 `[]`)
- `featured` 불린 (선택사항, 기본값 `false`)

### 4.2 마크다운 렌더링

- Astro의 `render()` 함수 사용
- PostLayout의 `.notion-content` 스타일 재사용
- 이미지, 코드 블록, 표, 인용구 등 완전 지원

### 4.3 네비게이션

**상세 페이지 → 포트폴리오 리스트:**
```astro
<a href="/portfolio/">← 포트폴리오 목록으로</a>
```

**선택사항 (향후):**
- 이전/다음 항목 네비게이션
- 카테고리 내 같은 항목 제안

---

## 5. 수용 기준 (Acceptance Criteria)

### 5.1 기능 요구사항

| ID | 요구사항 | 검증 방법 |
|----|---------|---------| 
| AC-1 | 포트폴리오 리스트에서 항목 클릭 시 `/portfolio/{category}/{slug}/` 경로로 이동 | URL 확인 |
| AC-2 | 상세 페이지에 제목, 설명, 날짜, 태그 메타데이터 표시 | 페이지 렌더링 확인 |
| AC-3 | 마크다운 본문 전체 콘텐츠 렌더링 (제목, 문단, 이미지, 코드, 표 등) | 시각적 검증 |
| AC-4 | 포트폴리오 목록으로 돌아가는 링크 작동 | 클릭 테스트 |
| AC-5 | featured 항목에 "Featured" 뱃지 표시 | 시각적 확인 |
| AC-6 | 모든 포트폴리오 항목(현재 10개)에 대해 상세 페이지 생성됨 | `npm run build` 성공 |

### 5.2 성능 요구사항

| ID | 요구사항 | 검증 방법 |
|----|---------|---------| 
| AC-7 | 빌드 시간 5초 이내 (포트폴리오 페이지 관련) | `npm run build` 실행 |
| AC-8 | 각 상세 페이지 로드 시간 < 1초 | Lighthouse/Network 탭 |

### 5.3 코드 품질

| ID | 요구사항 | 검증 방법 |
|----|---------|---------| 
| AC-9 | TypeScript 타입 안정성 (no `any`, no 타입 에러) | `npm run type-check` 통과 |
| AC-10 | 스타일 일관성 (PostLayout과 동일한 스타일 언어) | 코드 리뷰 |
| AC-11 | 접근성 준수 (ARIA 레이블, 시맨틱 HTML) | 코드 리뷰 |

---

## 6. 테스트 시나리오

### 6.1 정상 케이스

**TC-1: 포트폴리오 리스트에서 항목 클릭**
```
1. /portfolio 페이지 로드
2. AIEnginerring 탭의 "사내 통합 AI 에이전트 플랫폼 구축" 항목 클릭
3. /portfolio/AIEnginerring/ai-agent-platform/ 페이지 로드
4. 제목, 설명, 태그, 마크다운 본문 표시됨
5. "← 포트폴리오 목록으로" 클릭 → /portfolio 이동
```
**예상 결과:** 모든 단계 통과

**TC-2: 모든 카테고리의 항목 접근**
```
1. 각 카테고리(AIEnginerring, DataEngineering, AnalyticsEngineering, Governance) 확인
2. 각 카테고리의 모든 항목에 상세 페이지가 존재하는지 확인
```
**예상 결과:** 10개 모든 항목 접근 가능

**TC-3: 브라우저 뒤로가기**
```
1. 포트폴리오 상세 페이지에서 브라우저 뒤로가기 클릭
2. 포트폴리오 리스트 페이지로 돌아옴
```
**예상 결과:** 페이지 히스토리 유지

### 6.2 엣지 케이스

**TC-4: 특수문자가 포함된 제목 슬러그**
```
파일: "AdTech AI Agent (Gemini CLI).md"
예상 슬러그: "adtech-ai-agent-gemini-cli"
접근: /portfolio/AIEnginerring/adtech-ai-agent-gemini-cli/
```
**예상 결과:** 정상 로드

**TC-5: 매우 긴 마크다운 콘텐츠**
```
파일: "사내 통합 AI 에이전트 플랫폼 구축.md" (약 2000자 이상)
```
**예상 결과:** 전체 콘텐츠 렌더링, 페이지 로딩 시간 정상

**TC-6: 마크다운 내 이미지 링크**
```
마크다운: ![image](https://prod-files-secure.s3.us-west-2.amazonaws.com/...)
```
**예상 결과:** 이미지 정상 렌더링

**TC-7: 존재하지 않는 경로 접근**
```
URL: /portfolio/InvalidCategory/invalid-slug/
```
**예상 결과:** 404 에러 페이지 (기존 Astro 동작)

### 6.3 회귀 테스트

**TC-8: 기존 포트폴리오 리스트 페이지 영향 없음**
```
1. /portfolio 페이지 로드
2. 탭 네비게이션 작동 확인
3. 필터/검색 기능(있을 경우) 작동 확인
```
**예상 결과:** 모두 정상

**TC-9: 블로그 페이지 영향 없음**
```
1. /blog 페이지 로드
2. 블로그 포스트 상세 페이지 로드
```
**예상 결과:** 블로그 시스템 정상 작동

---

## 7. 구현 순서

1. **유틸리티 함수 추가** (`src/lib/portfolio.ts`)
   - `generateSlug()` 함수 구현
   - 슬러그 중복 검사 로직

2. **레이아웃 생성** (`src/layouts/PortfolioDetailLayout.astro`)
   - PostLayout 참고하여 작성
   - 메타데이터 렌더링
   - 마크다운 콘텐츠 렌더링

3. **동적 라우팅 페이지** (`src/pages/portfolio/[category]/[slug].astro`)
   - `getStaticPaths()` 구현
   - 레이아웃 연결

4. **리스트 페이지 수정** (`src/components/PortfolioTabs.astro`)
   - 각 항목을 클릭 가능한 링크로 변환
   - 기존 레이아웃 유지

5. **빌드 및 테스트**
   - `npm run build`
   - 수용 기준 검증

---

## 8. 이번 사이클에서 하지 않는 것 (Out of Scope)

| 항목 | 이유 |
|------|------|
| 포트폴리오 이전/다음 네비게이션 | 기본 기능 달성 후 향후 추가 가능 |
| 포트폴리오 아이템 추가/수정/삭제 UI | CMS 통합 고려 필요 (현재는 마크다운 파일 기반) |
| 포트폴리오 검색/필터링 기능 | 별도 요구사항으로 분리 |
| RSS 피드 (포트폴리오) | 블로그 피드와 별도 구현 필요 |
| 댓글 기능 | 향후 기능 |
| 소셜 공유 버튼 | 선택사항 (포스트에도 없음) |
| 다국어 지원 | 한국어 전용 유지 |

---

## 9. 의존성 및 제약사항

**의존성:**
- Astro 6.x (기존)
- `astro:content` collection API (기존)
- 마크다운 렌더링 (Astro 기본 지원)

**제약사항:**
- 포트폴리오 마크다운 파일명이 변경되면 슬러그도 재생성됨
- 깨진 이미지 링크는 사용자가 마크다운에서 수정해야 함

---

## 10. 추가 참고사항

### 10.1 블로그 포스트와의 차이점

| 항목 | 블로그 | 포트폴리오 |
|------|--------|----------|
| 파일 경로 | `src/content/posts/{category}/{slug}.md` | `src/content/portfolio/{category}/{slug}.md` |
| 라우팅 | `/blog/{slug}/` | `/portfolio/{category}/{slug}/` |
| 스타일 | 기존 `PostLayout` | `PortfolioDetailLayout` (PostLayout 기반) |
| 뒤로가기 링크 | `/blog/` | `/portfolio/` |

### 10.2 향후 확장 가능성

- 포트폴리오 항목별 댓글/피드백 기능
- 포트폴리오 항목 기여자 표시
- 기술 스택 인터랙티브 시각화
- 성과 지표 시각화 (메트릭)

---

**End of Specification**

문서 ID: `20260406-portfolio-detail-page`  
버전: 1.0  
상태: 검토 대기
