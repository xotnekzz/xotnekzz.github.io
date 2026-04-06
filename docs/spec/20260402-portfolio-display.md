# 스펙: 포트폴리오 콘텐츠 표시 기능

**작성자:** 기획 에이전트  
**작성일:** 2026-04-02  
**버전:** v1.0  
**상태:** 기획 완료

---

## 1. 목표 및 배경

### 1.1 목표
`src/content/portfolio/` 디렉토리에 정리된 포트폴리오 프로젝트 데이터를 `/portfolio` 페이지에 구조적으로 표시하는 기능 개발.

### 1.2 현재 상황
- `/portfolio` 히든 페이지가 이미 생성됨 (`src/pages/portfolio.astro`)
- 4개 카테고리 폴더 존재:
  - `AnalyticsEnginering/` (1개 항목)
  - `Governance/` (1개 항목)
  - `DataEngineering/` (4개 항목)
  - `AIEnginerring/` (3개 항목)
- 각 항목은 Markdown 파일 형식 (프론트매터 포함)
- **현재 상황:** 포트폴리오 페이지에 하드코딩된 콘텐츠 1개만 표시됨 ("이 사이트")

### 1.3 배경
포트폴리오 항목들이 파일 시스템에만 존재하고 페이지에 렌더링되지 않아, 사용자가 프로젝트 경험을 확인할 수 없는 상태. 블로그 포스트처럼 자동화된 콘텐츠 로딩 메커니즘을 구축하여 포트폴리오 데이터를 효율적으로 관리 및 표시.

---

## 2. 요구사항 분석

### 2.1 데이터 구조

#### 포트폴리오 파일 형식 (Markdown + Frontmatter)
```
src/content/portfolio/
├── DataEngineering/
│   ├── columnstore_to_starrocks.md
│   ├── ELT 파이프라인 설계 (PyAirbyte).md
│   ├── Event Driven Kafka Kraft.md
│   ├── Metadata Driven ETL Workflow.md
│   └── doris.md
├── AIEnginerring/
│   ├── AdTech AI Agent (Gemini CLI).md
│   ├── 사내 통합 AI 에이전트 플랫폼 구축.md
│   └── AI를 활용한 파이썬 모듈 문서 자동화하기.md
├── AnalyticsEnginering/
│   └── PROAS Prediction Data Pipeline.md
└── Governance/
    └── openmetadata.md
```

#### Frontmatter 스키마
모든 포트폴리오 파일은 다음 필드를 포함:
```yaml
---
title: string          # 프로젝트 제목 (필수)
description: string    # 프로젝트 한줄 설명 (필수)
date: YYYY-MM-DD      # 프로젝트 시작/완료 날짜 (필수)
tags: string[]        # 기술 스택/태그 (필수)
featured: boolean     # 메인 노출 여부 (선택)
---
```

**예시:**
```yaml
---
title: AdTech AI Agent (Gemini CLI)
description: Gemini CLI 기반 AI 에이전트로 1,500개 마케팅 캠페인 자동화
date: 2025-01-01
tags:
  - AI
  - Gemini
  - MCP
featured: true
---
```

### 2.2 페이지 표시 요구사항

#### 2.2.1 레이아웃 구조
```
Portfolio (메인 제목)
├── 카테고리 1: DataEngineering
│   ├── 프로젝트 카드 1
│   │   ├── 제목
│   │   ├── 설명
│   │   ├── 날짜
│   │   └── 태그
│   ├── 프로젝트 카드 2
│   └── ...
├── 카테고리 2: AIEnginerring
│   ├── 프로젝트 카드 1
│   └── ...
└── ...
```

#### 2.2.2 표시 항목 (카드 단위)
- **제목** (h3 헤더)
- **설명** (단일 줄, 회색 텍스트)
- **날짜** (소문자, 회색 텍스트, "YYYY년 M월" 형식)
- **태그** (인라인 스팬, 색상 적용)
- **선택 사항:** `featured: true` 항목에 배지/강조 표시

#### 2.2.3 스타일 요구사항
- 기존 블로그 스타일(`--color-*` CSS 변수) 재사용
- 카테고리별 시각적 구분 (섹션 구분선)
- 카드 간 균일한 간격
- 태그 스타일 통일 (기존 `--color-tag-bg`, `--color-tag-text` 사용)

#### 2.2.4 정렬 및 필터링
- **카테고리 정렬:** 폴더명 알파벳 순
- **항목 정렬:** 각 카테고리 내에서 `date` 필드 기준 내림차순 (최신 우선)
- **선택 사항:** `featured: true` 항목을 상단에 노출

---

## 3. 구현 계획

### 3.1 변경 대상 파일

#### 3.1.1 `src/pages/portfolio.astro` (필수)
**목표:** 포트폴리오 데이터 로딩 및 렌더링

**작업 내용:**
1. `src/content/portfolio/` 디렉토리에서 모든 카테고리 폴더 및 Markdown 파일 동적 로딩
   - Astro의 `Astro.glob()` 또는 `import.meta.glob()` 활용
2. Frontmatter 파싱 (프로젝트 메타데이터 추출)
3. 데이터 정렬:
   - 카테고리별 그룹화
   - 각 그룹 내 `date` 기준 내림차순
   - `featured` 필드 기준 상단 노출 (선택 사항)
4. 템플릿 렌더링:
   - 카테고리별 섹션
   - 각 섹션 내 프로젝트 카드

**예상 코드 구조:**
```astro
---
import BaseLayout from '../layouts/BaseLayout.astro';

// 1. 포트폴리오 파일 동적 로딩
const portfolioFiles = import.meta.glob('../content/portfolio/*/*.md', { eager: true });

// 2. 메타데이터 추출 및 정렬
const projects = Object.entries(portfolioFiles)
  .map(([path, module]) => ({
    path,
    ...module.frontmatter,
    // 카테고리 추출 (경로에서)
  }))
  .sort((a, b) => {
    // date 기준 내림차순
  });

// 3. 카테고리별 그룹화
const grouped = groupByCategory(projects);
---

<BaseLayout>
  <!-- 렌더링 -->
</BaseLayout>
```

#### 3.1.2 `src/lib/portfolio.ts` (신규 유틸리티, 선택 사항)
**목표:** 포트폴리오 데이터 처리 로직 분리

**작업 내용 (선택):**
- `Portfolio` 인터페이스 정의
- 데이터 정렬/필터링 함수 (`sortByDate`, `groupByCategory` 등)
- 경로 해석 함수 (카테고리 추출)

**선택 이유:** 코드 재사용성 및 테스트 가능성 향상

#### 3.1.3 `src/lib/types.ts` (필수 업데이트)
**목표:** 포트폴리오 타입 정의 추가

**작업 내용:**
```typescript
export interface Portfolio {
  title: string;
  description: string;
  date: string; // YYYY-MM-DD 형식
  tags: string[];
  featured?: boolean;
  category?: string; // 폴더명
}
```

---

## 4. 기술 스택 및 의존성

### 4.1 사용할 기술
- **Astro**: 정적 사이트 생성, 파일 기반 라우팅
- **TypeScript**: 타입 안정성
- **CSS 변수**: 기존 스타일 시스템 활용

### 4.2 새 의존성
- **없음** (기존 Astro 및 표준 라이브러리만 사용)

### 4.3 호환성
- **Node.js**: 18.x 이상 (기존 프로젝트 요구사항 유지)
- **Astro**: 5.x 이상

---

## 5. 수용 기준 (Acceptance Criteria)

### 5.1 기능 수용 기준

| # | 항목 | 검증 방법 | 예상 결과 |
|---|------|---------|---------|
| 1 | 빌드 성공 | `npm run build` 실행 | 빌드 완료, 오류 없음 |
| 2 | 포트폴리오 페이지 렌더링 | `npm run dev` 후 `/portfolio` 접속 | 페이지 정상 표시 |
| 3 | 모든 포트폴리오 항목 로딩 | HTML 소스 또는 DOM 검사 | 총 9개 항목 모두 표시됨 |
| 4 | 카테고리 섹션 표시 | 시각적 확인 | 4개 카테고리 섹션 분리 표시 |
| 5 | 메타데이터 표시 정확성 | 각 항목 제목, 설명, 날짜, 태그 확인 | 모든 필드 정확하게 렌더링 |
| 6 | 정렬 순서 검증 | 각 카테고리 내 날짜 확인 | 날짜 내림차순 (최신순) |
| 7 | 태그 렌더링 | 시각적 확인 | 모든 태그 색상 적용되어 표시 |
| 8 | 반응형 디자인 | 모바일 브라우저 (375px 이상) 확인 | 모바일에서 카드 레이아웃 유지 |

### 5.2 성능 수용 기준
- **페이지 로드 시간**: 1초 이내 (개발 서버 기준)
- **번들 크기 증가**: 50KB 미만 (Gzip)

### 5.3 코드 품질 기준
- **TypeScript 타입 커버리지**: 100% (포트폴리오 관련 모듈)
- **ESLint**: 경고 없음

---

## 6. 테스트 시나리오

### 6.1 정상 케이스 (Happy Path)

#### TC-1: 전체 포트폴리오 로드
```
Given: /portfolio 페이지 방문
When:  페이지 로드 완료
Then:  - 4개 카테고리 섹션 표시
       - 총 9개 프로젝트 항목 표시
       - 각 항목에 제목, 설명, 날짜, 태그 표시
```

#### TC-2: 날짜 정렬 검증
```
Given: DataEngineering 카테고리
When:  항목 목록 확인
Then:  - 첫 번째: 2024-01-01 이후 (columnstore_to_starrocks)
       - 순서가 날짜 내림차순 (최신순)
```

#### TC-3: 태그 표시
```
Given: 임의의 포트폴리오 항목
When:  항목 태그 확인
Then:  - 모든 태그가 스타일 적용되어 표시됨
       - 태그 색상이 CSS 변수 적용됨
```

### 6.2 엣지 케이스 (Edge Cases)

#### TC-4: 카테고리 폴더 비어 있을 경우
```
Given: 카테고리 폴더에 파일 없음
When:  포트폴리오 페이지 로드
Then:  - 빌드 오류 없음
       - 해당 카테고리 섹션 미표시 (또는 "항목 없음" 메시지)
```

#### TC-5: 필드 누락 (Frontmatter 불완전)
```
Given: Markdown 파일 frontmatter에 필수 필드 누락 (e.g., date)
When:  포트폴리오 페이지 빌드
Then:  - 빌드 경고/오류 발생 (선택: 타입 검증)
       - 또는 기본값으로 처리되어 페이지 표시
```

#### TC-6: 매우 긴 설명 텍스트
```
Given: 설명 필드가 200자 이상
When:  포트폴리오 페이지 렌더링
Then:  - 텍스트 자르기 또는 개행 처리됨
       - 카드 레이아웃 깨지지 않음
```

#### TC-7: 특수 문자 및 다국어
```
Given: 제목/설명에 한글, 이모지, 기호 포함
When:  포트폴리오 페이지 렌더링
Then:  - 모든 문자 정상 표시
       - HTML 이스케이프 처리됨
```

### 6.3 회귀 테스트

#### TC-8: 기존 CSS 변수 호환성
```
Given: 기존 블로그 스타일 (`--color-*`)
When:  포트폴리오 페이지 렌더링
Then:  - 모든 색상이 기존 테마와 동일하게 적용됨
       - 스타일 시스템 호환성 유지
```

#### TC-9: 블로그 페이지 영향도 검증
```
Given: 포트폴리오 기능 추가 후
When:  블로그 페이지 (`/blog`) 접속
Then:  - 블로그 페이지 정상 작동
       - 레이아웃/스타일 변화 없음
```

---

## 7. 이번 사이클에서 하지 않는 것 (Out of Scope)

### 7.1 제외 기능
- [x] **포트폴리오 상세 페이지** (`/portfolio/[id]`) — 향후 사이클
- [x] **포트폴리오 검색/필터 기능** — 향후 사이클
- [x] **포트폴리오 카드 컴포넌트 분리** — 기능 검증 후 리팩토링 고려
- [x] **Notion API 연동** — 파일 시스템 기반으로 진행
- [x] **이미지/썸네일 처리** — 추후 확장 기능
- [x] **포트폴리오 데이터 Validation 스키마** — 선택 사항 (사이클 종료 후 고려)

### 7.2 의도적 제한사항
- **자동 생성**: 포트폴리오 메타데이터는 수동 입력 (자동 생성 안 함)
- **메인 페이지**: 포트폴리오 항목을 메인 페이지(`/`)에 표시하지 않음 (분리 유지)

---

## 8. 개발 체크리스트

- [ ] `src/content/portfolio/` 폴더 구조 확인
- [ ] `src/lib/types.ts`에 `Portfolio` 인터페이스 추가
- [ ] `src/lib/portfolio.ts` (선택) 유틸리티 함수 작성
- [ ] `src/pages/portfolio.astro` 업데이트:
  - [ ] 파일 동적 로딩 구현
  - [ ] 메타데이터 파싱 및 정렬
  - [ ] 템플릿 렌더링
- [ ] CSS/스타일링 검증
- [ ] 모든 테스트 시나리오 검증
- [ ] 빌드 및 배포 검증

---

## 9. 예상 산출물

### 9.1 코드 변경사항
- `src/pages/portfolio.astro` (업데이트)
- `src/lib/types.ts` (업데이트)
- `src/lib/portfolio.ts` (신규, 선택)

### 9.2 문서
- 이 스펙 문서 (완료)
- 개발 에이전트를 위한 구현 가이드 (별도 문서로 전달)

### 9.3 배포
- GitHub Pages에 자동 배포 (CI/CD)
- 변경사항 없음 (기존 배포 프로세스 유지)

---

## 10. 참고 자료

- **Astro 공식 문서**: https://docs.astro.build
- **프로젝트 스택**: `/docs/stack.md`
- **블로그 구현 참고**: `src/pages/blog/index.astro`

---

## 11. 승인 및 진행

**기획 완료:** 2026-04-02  
**다음 단계:** 개발 에이전트 할당 및 구현 시작
