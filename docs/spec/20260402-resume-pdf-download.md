# 스펙: 이력서 PDF 다운로드 기능

**작성일**: 2026-04-02  
**에이전트**: Planner Agent  
**상태**: 스펙 정의 완료  
**우선순위**: P2 (UI 개선)

---

## 1. 목표 및 배경

### 목표
이력서 페이지에 PDF 다운로드 기능을 추가하여 사용자가 현재 표시되는 UI/UX 스타일을 그대로 유지한 PDF 파일로 저장할 수 있도록 지원.

### 배경 및 필요성
- **현재 상황**: 이력서 페이지는 웹 기반 HTML로만 제공되며, 오프라인이나 제3자에게 공유하기 위한 표준 형식(PDF)이 부재
- **사용자 요구**: "페이지의 현재 스타일을 유지하면서 PDF로 저장하고 싶음"
- **비즈니스 가치**: 
  - 채용 과정에서 이메일 공유 시 PDF 형식의 표준화된 자료 제공
  - 이력서 다양한 배포 채널 지원 (이메일, LinkedIn, 면접 현장 등)
  - 사용자의 포트폴리오 사이트에서 다운로드 가능한 산출물 확보

---

## 2. 기술 방식 검토

### 옵션 비교

| 항목 | html2pdf.js | Puppeteer |
|------|-------------|-----------|
| **위치** | 클라이언트 사이드 | 서버 사이드 |
| **패키지 크기** | ~20KB (gzip) | ~300MB+ |
| **설정 복잡도** | 낮음 | 높음 (서버 설정 필요) |
| **CSS 지원** | 좋음 (대부분의 CSS 속성) | 최고 (완벽한 렌더링) |
| **다크모드 지원** | ✓ (DOM 상태 기반) | ✓ (환경 변수 필요) |
| **배포 환경** | 정적 호스팅 가능 | Node.js 런타임 필수 |
| **즉시 구현** | ✓ | ✗ |

### 선택 사항
**html2pdf.js 선택**
- 이유: 정적 사이트(Astro on GitHub Pages)에서 클라이언트 사이드 구현이 최적
- 이점: 별도 서버 구축 불필요, npm 패키지 추가 최소화, 즉시 구현 가능
- 제약: CSS 일부 고급 기능(복잡한 그림자, 특수 글꼴 렌더링) 미지원 가능성 있으나, 현재 이력서 스타일에서는 영향 없음

---

## 3. 변경 대상 파일

### 3.1 수정 파일

#### `src/pages/resume.astro`
**변경 내용**:
- Hero 섹션 내 버튼 추가 공간 확보 (이메일/GitHub/포트폴리오 링크 아래에 배치)
- "PDF 다운로드" 버튼 UI 추가
- 클라이언트 사이드 스크립트 통합 (`<script>` 태그)

**구체적 변경점**:
```
Hero 섹션 (line 20~56):
  - 현재: <div class="flex flex-wrap gap-4 text-sm"> (링크들)
  - 변경 후: 
    - 링크 div는 유지
    - 새로운 라인 추가: <button id="pdf-download-btn"> PDF 다운로드 </button>
```

**버튼 스타일**:
- 외형: `color: var(--color-accent)`, 호버 시 `var(--color-accent-hover)`
- 레이아웃: 링크들과 동일한 `gap-4` 적용, flex wrap 유지
- 텍스트: "PDF 다운로드"
- 접근성: `aria-label="이력서를 PDF로 다운로드"`

#### `src/pages/resume.astro` (클라이언트 스크립트)
**추가 내용**:
```html
<script is:inline>
// html2pdf 라이브러리 동적 로드 + PDF 생성 함수
</script>
```

**스크립트 기능**:
1. html2pdf 라이브러리 CDN 로드 (`https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js`)
2. 버튼 클릭 이벤트 리스너 등록
3. PDF 생성 시점의 DOM 상태(현재 다크/라이트 모드) 캡처
4. `김태수_이력서.pdf` 또는 `tskim_resume.pdf` 이름으로 다운로드

### 3.2 신규 파일 (필요시)
- 신규 파일 추가 없음 (클라이언트 스크립트는 `resume.astro`에 인라인 포함)

---

## 4. 구현 상세 스펙

### 4.1 html2pdf 라이브러리 사용법

```javascript
const element = document.getElementById('resume-content'); // 또는 <main> 전체
const options = {
  margin: [10, 10, 10, 10],        // mm 단위 여백
  filename: '김태수_이력서.pdf',
  image: { type: 'jpeg', quality: 0.98 },
  html2canvas: {
    scale: 2,                        // 고해상도 (DPI 향상)
    useCORS: true,                  // CORS 처리
    allowTaint: true,               // 외부 이미지 포함 허용
    backgroundColor: 'var(--color-bg)' // 현재 테마 배경색
  },
  jsPDF: {
    orientation: 'portrait',
    unit: 'mm',
    format: 'a4'
  }
};

html2pdf().set(options).from(element).save();
```

### 4.2 DOM 선택 전략

**선택지**:
1. **전체 이력서 콘텐츠** (권장):
   - `<main>` 요소 전체 선택 (BaseLayout 내 구조)
   - 장점: 모든 섹션 포함, 레이아웃 일관성
   
2. **특정 섹션만**:
   - Hero만, 또는 특정 섹션만 제외
   - 고려: 현재 요구사항에서 전체 포함 필요

**최종 선택**: `document.querySelector('main')` → 전체 이력서 포함

### 4.3 다크/라이트 모드 지원

**구현 방식**:
- html2pdf는 PDF 생성 시점의 DOM 상태(CSS 변수값, 배경색, 텍스트색)를 그대로 캡처
- `[data-theme="dark"]` 속성이 설정된 상태에서 버튼 클릭 시 다크 모드로 PDF 생성
- 라이트 모드 상태에서 클릭 시 라이트 모드로 생성

**추가 처리**:
- html2canvas의 `backgroundColor` 옵션에 CSS 변수 직접 사용 불가 → JavaScript로 런타임에 계산
  ```javascript
  const bgColor = getComputedStyle(document.documentElement).getPropertyValue('--color-bg').trim();
  ```

### 4.4 파일명 및 다운로드 처리

**파일명**: `김태수_이력서.pdf`
- 이유: 한글 가능, 명확한 이력서 식별
- 대안: `tskim_resume.pdf` (영문, 국제적 호환성)

**최종 선택**: `김태수_이력서.pdf` (한국 시장 타겟)

**다운로드 구현**:
- html2pdf의 `.save()` 메서드가 자동으로 다운로드 트리거
- 브라우저 기본 다운로드 동작 사용 (별도 처리 불필요)

---

## 5. 수용 기준 (Acceptance Criteria)

### 5.1 기능 요구사항

- [ ] 이력서 페이지 Hero 섹션에 "PDF 다운로드" 버튼이 표시됨
- [ ] 버튼 클릭 시 `김태수_이력서.pdf` 파일이 다운로드됨
- [ ] 다운로드된 PDF에 이력서의 모든 섹션이 포함됨:
  - [ ] Hero (이름, 직책, 연락처)
  - [ ] Professional Summary
  - [ ] Professional Experience (전체 타임라인 포함)
  - [ ] Core Technical Stack
  - [ ] Education
- [ ] PDF 페이지 크기: A4, 세로 방향

### 5.2 스타일 및 테마 요구사항

- [ ] **라이트 모드 PDF**: 
  - 배경색: `#ffffff` (흰색)
  - 텍스트색: `#1a1a1a` (검은색)
  - 강조색: `#2563eb` (파란색)
  - 태그 배경: `#eff6ff` (연한 파란색)
  
- [ ] **다크 모드 PDF**:
  - 배경색: `#141414` (검은색)
  - 텍스트색: `#e8e8e8` (흰색)
  - 강조색: `#60a5fa` (라이트 파란색)
  - 태그 배경: `#1e2a3a` (짙은 파란색)

- [ ] 현재 표시 중인 테마(다크/라이트) 상태가 PDF에 반영됨

### 5.3 레이아웃 및 시각 요구사항

- [ ] PDF의 텍스트 크기 및 비율이 화면 표시와 일치
- [ ] 제목 계층 구조 (h1, h2, h3) 유지
- [ ] Timeline 시각화 (timeline dot, border-left) 포함
- [ ] 태그(skill badges) 스타일 유지
- [ ] 리스트 항목 및 들여쓰기 유지

### 5.4 사용성 및 접근성

- [ ] 버튼이 시각적으로 다른 링크들과 구분됨 (일관된 스타일)
- [ ] 버튼에 `aria-label` 속성 포함
- [ ] 버튼 호버/포커스 상태 제공
- [ ] 다운로드 진행 중 사용자 피드백 (선택사항: 로딩 표시)

### 5.5 성능 요구사항

- [ ] 첫 페이지 로드 시 html2pdf 라이브러리 로드 지연 없음 (CDN 비동기 로드)
- [ ] PDF 생성 소요 시간 < 2초 (사용자 체감 순간)
- [ ] 파일 크기 < 2MB (네트워크 효율성)

### 5.6 브라우저 호환성

- [ ] Chrome/Chromium 최신 버전 ✓
- [ ] Firefox 최신 버전 ✓
- [ ] Safari 최신 버전 ✓
- [ ] Edge 최신 버전 ✓

---

## 6. 테스트 시나리오

### 6.1 정상 케이스 (Happy Path)

**TC-1: 라이트 모드에서 PDF 다운로드**
```
전제 조건:
  - 이력서 페이지 접속
  - 라이트 모드 활성화
  
실행 단계:
  1. "PDF 다운로드" 버튼 클릭
  2. 다운로드 대화상자 또는 자동 다운로드 발생 확인
  3. 다운로드 파일명 확인: 김태수_이력서.pdf
  
예상 결과:
  - 파일이 정상적으로 다운로드됨
  - PDF 열었을 때 배경색이 흰색(#ffffff)
  - 텍스트 및 모든 콘텐츠가 명확히 표시됨
```

**TC-2: 다크 모드에서 PDF 다운로드**
```
전제 조건:
  - 이력서 페이지 접속
  - 다크 모드 활성화 ([data-theme="dark"] 적용)
  
실행 단계:
  1. "PDF 다운로드" 버튼 클릭
  2. 다운로드 완료 확인
  
예상 결과:
  - 파일이 정상적으로 다운로드됨
  - PDF 열었을 때 배경색이 검은색(#141414)
  - 텍스트 색상이 흰색(#e8e8e8)으로 표시됨
```

**TC-3: 모든 섹션 포함 확인**
```
전제 조건:
  - 이력서 페이지 접속
  - PC/노트북에서 전체 페이지 스크롤 확인
  
실행 단계:
  1. "PDF 다운로드" 버튼 클릭
  2. 생성된 PDF 파일 열기
  3. 각 섹션 확인:
     - Hero (이름: 김태수, 직책: Senior Data Engineer, 연락처)
     - Professional Summary (약 2~3개 문단)
     - Professional Experience (비트망고 6개 프로젝트, 우암 1개 프로젝트)
     - Core Technical Stack (6개 카테고리)
     - Education (성공회대학교)
  4. 페이지 수 확인 (대략 3~5페이지 예상)
  
예상 결과:
  - 모든 섹션이 PDF에 포함됨
  - 레이아웃이 웹과 동일하게 유지됨
  - 텍스트 흐름이 자연스러움 (줄바꿈 적절)
```

### 6.2 엣지 케이스

**TC-4: 모바일 환경에서 다운로드**
```
전제 조건:
  - 모바일 디바이스(iPhone, Android)에서 이력서 페이지 접속
  
실행 단계:
  1. "PDF 다운로드" 버튼 클릭
  
예상 결과:
  - 모바일 브라우저에서도 PDF 다운로드 가능
  - 파일 저장 대화상자 또는 자동 저장 (기기 설정에 따름)
  - PDF 생성 중 오류 없음
```

**TC-5: 테마 전환 직후 다운로드**
```
전제 조건:
  - 이력서 페이지 접속
  - 라이트 모드 활성
  
실행 단계:
  1. 테마 전환 버튼 클릭 (다크 모드로 변경)
  2. 즉시 "PDF 다운로드" 버튼 클릭 (전환 직후)
  
예상 결과:
  - PDF가 다크 모드 스타일로 생성됨
  - 테마 전환 중 렌더링 오류 없음
```

**TC-6: 빠른 연속 클릭**
```
전제 조건:
  - 이력서 페이지 접속
  
실행 단계:
  1. "PDF 다운로드" 버튼을 2~3초 간격으로 빠르게 클릭 (3회)
  
예상 결과:
  - 각 클릭마다 별도의 PDF 파일이 다운로드됨
  - 파일명이 브라우저 기본 정책에 따라 처리됨 (예: 파일명 (1).pdf)
  - 메모리 누수나 렌더링 오류 없음
```

### 6.3 성능 테스트

**TC-7: PDF 생성 시간 측정**
```
전제 조건:
  - 이력서 페이지 로드 완료
  
실행 단계:
  1. 개발자 도구 > Performance 탭 열기
  2. "PDF 다운로드" 버튼 클릭
  3. PDF 생성 완료까지의 시간 기록
  
예상 결과:
  - PDF 생성 시간 < 2초
  - 브라우저 응답성 유지 (UI 프리징 없음)
```

**TC-8: 파일 크기 확인**
```
전제 조건:
  - 이력서 페이지 접속
  
실행 단계:
  1. "PDF 다운로드" 버튼 클릭
  2. 다운로드된 파일 속성 확인
  
예상 결과:
  - 파일 크기 < 2MB
  - 고화질 렌더링 유지 (72 DPI 이상)
```

### 6.4 회귀 테스트 (Regression)

**TC-9: 기존 이력서 페이지 기능 유지**
```
전제 조건:
  - 이력서 페이지 접속
  
실행 단계:
  1. 이메일 링크 클릭 (메일 클라이언트 열림 확인)
  2. GitHub 링크 클릭 (새 탭에서 GitHub 페이지 열림 확인)
  3. Portfolio 링크 클릭 (새 탭에서 포트폴리오 페이지 열림 확인)
  4. 페이지 테마 전환 (라이트 ↔ 다크) 확인
  
예상 결과:
  - 모든 기존 링크 및 기능이 정상 작동
  - 테마 전환이 부드럽게 작동
  - PDF 다운로드 버튼 추가가 다른 기능에 영향 없음
```

---

## 7. 이번 사이클에서 하지 않는 것 (Out of Scope)

### 7.1 제외 사항

| 항목 | 이유 |
|------|------|
| **PDF 편집 기능** | 이 사이클의 목표는 다운로드 기능만, 편집은 별도 요청 시 추진 |
| **다국어 파일명** | 영문 파일명(`tskim_resume.pdf`) 지원은 v2에서 추진 |
| **서명란 추가** | 채용 과정에서 필요시 별도 요청 기반 추진 |
| **자동 이메일 발송** | PDF 생성 후 이메일로 자동 발송 기능은 별도 요청 |
| **클라우드 저장소 연동** | Google Drive, Dropbox 자동 저장은 v2 |
| **PDF 페이지 커스터마이징** | 다중 페이지 레이아웃, 헤더/푸터 추가는 v2 |
| **Puppeteer 서버 구축** | 클라이언트 사이드 솔루션으로 충분함 |
| **이력서 실시간 편집 UI** | PDF 다운로드와 독립적인 기능 |

### 7.2 향후 고려사항 (Backlog)

- **v2**: 영문 파일명 옵션, 사용자 커스텀 파일명 입력
- **v3**: 서명란 추가, PDF 페이지 레이아웃 커스터마이징
- **v4**: 클라우드 저장소 자동 업로드 (Google Drive, OneDrive 등)
- **v5**: 이력서 버전 관리 (PDF 생성 이력 추적)

---

## 8. 구현 로드맵

### Phase 1: 코어 기능 개발 (이번 사이클)
1. html2pdf 라이브러리 CDN 링크 추가
2. Hero 섹션에 "PDF 다운로드" 버튼 UI 추가
3. 클라이언트 스크립트 작성 (pdf 생성 로직)
4. 다크/라이트 모드 지원 구현

### Phase 2: 테스트 및 검증
1. 모든 테스트 시나리오(TC-1 ~ TC-9) 실행
2. 크로스 브라우저 검증 (Chrome, Firefox, Safari, Edge)
3. 모바일 환경 테스트
4. 성능 최적화 (필요시)

### Phase 3: 배포
1. 개발 브랜치에서 main으로 PR 생성
2. Code Review 및 병합
3. GitHub Pages 자동 배포 확인

---

## 9. 기술 리소스

### 9.1 라이브러리 선택

**html2pdf.js**
- CDN: `https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js`
- 라이센스: MIT
- 문서: [html2pdf.js GitHub](https://github.com/eKoopmans/html2pdf)

### 9.2 참고 코드 패턴

```html
<!-- 버튼 HTML -->
<button 
  id="pdf-download-btn" 
  class="hover:underline"
  style="color: var(--color-accent);"
  aria-label="이력서를 PDF로 다운로드"
>
  PDF 다운로드
</button>

<!-- 스크립트 -->
<script is:inline>
  // CDN 라이브러리 동적 로드
  function loadHtml2pdf() {
    return new Promise((resolve) => {
      if (window.html2pdf) {
        resolve();
        return;
      }
      const script = document.createElement('script');
      script.src = 'https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js';
      script.onload = resolve;
      document.head.appendChild(script);
    });
  }

  // PDF 생성 함수
  async function generatePDF() {
    await loadHtml2pdf();
    
    const element = document.querySelector('main');
    const bgColor = getComputedStyle(document.documentElement)
      .getPropertyValue('--color-bg')
      .trim();
    
    const options = {
      margin: [10, 10, 10, 10],
      filename: '김태수_이력서.pdf',
      image: { type: 'jpeg', quality: 0.98 },
      html2canvas: {
        scale: 2,
        useCORS: true,
        allowTaint: true,
        backgroundColor: bgColor
      },
      jsPDF: {
        orientation: 'portrait',
        unit: 'mm',
        format: 'a4'
      }
    };
    
    html2pdf().set(options).from(element).save();
  }

  // 버튼 이벤트 리스너
  document.addEventListener('DOMContentLoaded', () => {
    const btn = document.getElementById('pdf-download-btn');
    if (btn) {
      btn.addEventListener('click', generatePDF);
    }
  });
</script>
```

---

## 10. 의존성 및 위험 요소

### 10.1 기술적 의존성
- **html2pdf.js CDN**: 외부 CDN 의존성, 다운시 대체 방안 필요
  - 완화: 로컬 npm 패키지 설치로 변경 가능

### 10.2 위험 요소

| 위험 | 영향도 | 확률 | 완화 방안 |
|------|--------|------|---------|
| CSS 렌더링 불일치 | 중 | 낮음 | html2pdf 옵션 튜닝, 폴백 스타일링 |
| 큰 이미지/콘텐츠로 인한 성능 저하 | 중 | 낮음 | 현재 이력서에 이미지 없음, 모니터링 |
| 다크 모드 색상 계산 오류 | 낮음 | 매우낮음 | CSS 변수 명확한 정의 유지 |
| 모바일 다운로드 실패 | 중 | 낮음 | 별도 모바일 테스트 진행 |

### 10.3 완화 전략
1. CDN 다운 시 로컬 npm 패키지로 전환 계획
2. 테스트 단계에서 엣지 케이스 조기 발견
3. 사용자 피드백 모니터링 (GA 이벤트 추가 고려)

---

## 11. 성공 지표

### 11.1 정량적 지표

- **기능 완성도**: 모든 Acceptance Criteria 충족 (100%)
- **테스트 커버리지**: 모든 TC-1~TC-9 통과 (100%)
- **크로스 브라우저 호환성**: 주요 브라우저 4개 이상에서 작동 (Chrome, Firefox, Safari, Edge)
- **PDF 품질**: 원본과 대비 시각적 일치도 > 95%
- **성능**: PDF 생성 시간 < 2초, 파일 크기 < 2MB

### 11.2 정성적 지표

- 사용자 만족도: 피드백 수집 및 개선안 도출
- 코드 품질: 리뷰어 승인 (Peer Review)
- 문서 완성도: 이 스펙 문서 기반 개발 완료

---

## 12. 검토 이력

| 날짜 | 검토자 | 상태 | 비고 |
|------|--------|------|------|
| 2026-04-02 | Planner Agent | 스펙 정의 완료 | - |
| (예정) | Developer Agent | 개발 진행 중 | - |
| (예정) | QA Agent | 검증 진행 | - |

---

## 13. 참고 자료

- [html2pdf.js GitHub Repository](https://github.com/eKoopmans/html2pdf)
- [html2pdf.js Documentation](https://ekoopmans.github.io/html2pdf.js/)
- [Astro 공식 문서](https://docs.astro.build/)
- [현재 이력서 페이지 코드](../../../src/pages/resume.astro)
- [CSS 변수 정의](../../../src/styles/global.css)
