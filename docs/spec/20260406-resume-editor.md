# 스펙: 개발 모드 이력서 UI 에디터

- **날짜**: 2026-04-06
- **사이클**: #3
- **작성자**: 기획 에이전트

---

## 목표

개발 모드(`npm run dev`)에서 이력서 페이지의 각 UI 레이아웃(섹션) 위에 마우스를 올렸을 때 수정 아이콘을 표시하고, 클릭 시 모달창을 띄워 텍스트를 직접 편집할 수 있는 기능을 제공한다. 이를 통해 개발자는 Notion API나 데이터베이스 없이도 로컬에서 빠르게 이력서 콘텐츠를 임시로 수정하고 미리보기할 수 있다.

**배경:** QA 보고서의 "다음 사이클 선택 항목" 中 포트폴리오 상세 페이지 및 필터 기능 구현 전, 개발 편의성을 높이기 위한 선제적 기능 요청. 이력서는 자주 업데이트되는 콘텐츠이므로 개발 모드에서의 빠른 반복 편집이 필요함.

---

## 변경 대상 파일

```
src/pages/resume.astro              — 개발 모드 전용 에디터 UI 및 초기화 로직 추가
src/data/resume.ts                  — 편집 가능하도록 상태 변수 추가 (선택사항, 백엔드 상태 관리)
src/components/ResumeEditor.astro   — 신규 컴포넌트: 모달 UI 및 에디터 핸들러
src/styles/global.css               — 모달 및 에디터 UI 스타일 추가
```

---

## 수용 기준 (Acceptance Criteria)

검증 에이전트가 PASS/FAIL을 판정할 수 있도록 **측정 가능하게** 작성한다.

- [ ] AC-1: `npm run build`가 오류 없이 성공하며, 프로덕션 빌드에 에디터 UI가 포함되지 않는다 (개발 모드 전용)
- [ ] AC-2: `npm run dev`로 개발 서버 시작 후 `/resume` 접속 시, 5개 섹션(Hero, Professional Summary, Professional Experience, Core Technical Stack, Education)에 마우스 호버 시 에디터 아이콘(✏️ 또는 pencil-icon)이 표시된다
- [ ] AC-3: 에디터 아이콘 클릭 시 모달 다이얼로그가 나타나며, 해당 섹션의 필드들이 입력 폼으로 렌더링된다 (textarea 또는 input[type=text])
- [ ] AC-4: 모달에서 텍스트를 수정 후 "저장" 버튼 클릭 시 페이지의 해당 섹션이 즉시 업데이트된다 (DOM 업데이트, 새로고침 불필요)
- [ ] AC-5: 모달에서 "취소" 버튼 또는 배경 클릭 시 모달이 닫히고 이전 상태로 복원된다 (데이터 변경 없음)
- [ ] AC-6: 페이지 새로고침 후 수정 사항은 유지되지 않는다 (localStorage 미사용, 개발 중 편의성만 제공)
- [ ] AC-7: 프로덕션 환경(built 파일)에서 에디터 UI 및 관련 스크립트가 완전히 제거되어, 빌드 크기 증가가 최소화된다 (HTML에 editable 속성, data-editable 선택자, 에디터 스크립트 미포함)
- [ ] AC-8: TypeScript 타입 검증 오류가 0개이며, 모든 에디터 관련 코드가 타입 안전하다 (`npx tsc --noEmit`)

---

## 테스트 시나리오

### 정상 케이스

#### 테스트 1: 개발 모드 진입 및 에디터 UI 표시
1. `npm run dev` 실행
2. 브라우저에서 `http://localhost:4321/resume/` 접속
3. **예상 결과**: 
   - 이력서 페이지 정상 렌더링
   - "Professional Summary" 섹션 위에 마우스 호버 → 에디터 아이콘 표시 (AC-2)
   - 다른 4개 섹션도 호버 시 동일하게 아이콘 표시

#### 테스트 2: 모달 열기 및 필드 편집
1. "Professional Summary" 섹션의 에디터 아이콘 클릭
2. **예상 결과**:
   - 모달 다이얼로그 표시 (AC-3)
   - 현재 요약(summary) 텍스트가 textarea에 채워짐
   - 모달 제목: "Professional Summary 편집"
3. textarea 텍스트 일부 수정 (예: 끝에 "테스트 추가" 문구 추가)
4. "저장" 버튼 클릭
5. **예상 결과**:
   - 모달 닫힘
   - 페이지의 Professional Summary 섹션 텍스트 즉시 반영 (AC-4)
   - 새로고침 없이 변경 사항 유지

#### 테스트 3: 모달 닫기 (취소)
1. "Professional Experience" 섹션의 에디터 아이콘 클릭
2. 모달이 열림
3. 텍스트 수정 (하지만 저장하지 않음)
4. "취소" 버튼 또는 모달 배경 클릭
5. **예상 결과**:
   - 모달 닫힘
   - 페이지 데이터 변경 없음 (수정 사항 미반영) (AC-5)

#### 테스트 4: 페이지 새로고침 후 상태
1. Professional Summary 섹션 수정 및 저장
2. 브라우저 새로고침 (F5 또는 Cmd+R)
3. **예상 결과**:
   - 페이지 로드 완료
   - Professional Summary 섹션이 원래 내용으로 복원 (AC-6)
   - 수정 사항 미유지

#### 테스트 5: 프로덕션 빌드 검증
1. `npm run build` 실행
2. `dist/resume/index.html` 파일 검사 (브라우저 DevTools > Elements 또는 파일 시스템)
3. **예상 결과**:
   - HTML에 `data-editable`, `editable` 속성 미포함
   - `ResumeEditor` 컴포넌트 관련 스크립트 미포함
   - 에디터 아이콘 또는 모달 마크업 미포함 (AC-7)

### 엣지 케이스

#### 테스트 6: 긴 텍스트 입력
1. "Professional Summary" 모달 열기
2. 현재 텍스트를 3배 길이의 텍스트로 교체 (예: 원래 500자 → 1500자)
3. "저장" 클릭
4. **예상 결과**:
   - 모달 닫힘
   - 페이지 레이아웃 깨지지 않음 (텍스트 오버플로우 처리, 줄바꿈 정상)
   - 모든 텍스트 표시됨

#### 테스트 7: 특수문자 및 HTML 입력
1. "Professional Summary" 모달 열기
2. 텍스트에 `<script>alert('test')</script>`, `&`, `"`, `'` 등 특수문자 포함
3. "저장" 클릭
4. **예상 결과**:
   - 페이지 업데이트 후 특수문자 정상 렌더링 (이스케이프 처리됨)
   - XSS 공격 미발생

#### 테스트 8: 빈 텍스트 입력
1. "Professional Summary" 모달 열기
2. textarea의 모든 텍스트 삭제
3. "저장" 클릭
4. **예상 결과**:
   - 모달 닫힘
   - 페이지의 Professional Summary 섹션 텍스트 영역 공백 표시
   - 레이아웃 구조 유지

#### 테스트 9: 여러 섹션 연속 편집
1. Professional Summary 섹션 수정 및 저장
2. 바로 Professional Experience 섹션의 모달 열기
3. Professional Experience 수정 후 저장
4. **예상 결과**:
   - 두 섹션 모두 정상 반영
   - 모달 상태 충돌 없음

#### 테스트 10: 개발 모드 전용 동작 확인
1. `npm run dev`에서 에디터 UI 정상 동작 확인 (위의 테스트 1-4)
2. `npm run build && npm run preview` 실행 (프로덕션 모드 미리보기)
3. **예상 결과**:
   - `/resume` 접속 시 에디터 아이콘 미표시
   - 마우스 호버 시 스타일 변화 없음

---

## 기술 설계

### 아키텍처

#### 1. 개발 모드 감지
```typescript
// resume.astro
const isDev = import.meta.env.DEV;
```
- Astro의 `import.meta.env.DEV`를 이용해 개발 모드 여부 판정
- 프로덕션 빌드에서는 이 조건이 `false`로 변환되어 에디터 코드가 제거됨 (Tree-shaking)

#### 2. 섹션 마크업
```html
<!-- resume.astro -->
{isDev && (
  <section data-editable="professional-summary" class="editable-section">
    <!-- ... -->
  </section>
)}
```
- `data-editable` 속성으로 각 섹션 식별
- `editable-section` 클래스로 호버 스타일 적용

#### 3. 모달 컴포넌트
- 신규 `src/components/ResumeEditor.astro` 컴포넌트
- 에디터 아이콘 클릭 시 모달 표시
- 섹션별 입력 폼 필드 렌더링

#### 4. 클라이언트 사이드 상태 관리
- JavaScript 객체를 이용한 메모리 내 상태 관리 (localStorage 미사용)
- 각 섹션의 현재 데이터를 전역 상태에 저장
- 저장 시 DOM 업데이트, 취소 시 상태 롤백

---

## 구현 가이드 라인

### 스타일
- 기존 CSS 변수 재사용: `--color-accent`, `--color-bg-secondary`, `--color-text` 등
- 모달 오버레이: 반투명 검정색 배경, z-index 1000
- 에디터 아이콘: Tailwind CSS `group-hover:opacity-100` 또는 CSS 전환

### 마크업
- Semantic HTML: `<dialog>` 또는 `<div role="dialog">`
- 접근성: `aria-label`, `aria-modal="true"`, Escape 키로 모달 닫기 지원

### 타입 안전성
```typescript
// 에디터 상태 인터페이스
interface ResumeEditorState {
  [key: string]: {
    isDirty: boolean;
    data: Record<string, string>;
  };
}
```

### 섹션별 편집 필드 정의

#### Professional Summary
- 필드: 1개 (summary)
- 입력 유형: textarea (줄바꿈 포함)

#### Professional Experience
- 필드: company, companyEn, period, role (회사별)
  - 각 experience 항목별로 편집 가능
- 입력 유형: input[type=text] (각 필드)

#### Core Technical Stack
- 필드: category, skills (카테고리별)
- 입력 유형: input[type=text] (category), textarea (skills는 쉼표 구분)

#### Education
- 필드: school, major, period
- 입력 유형: input[type=text]

#### Hero (Personal Info)
- 필드: name, title, email, github
- 입력 유형: input[type=text]

---

## 이번 사이클에서 하지 않는 것

- **데이터 저장**: localStorage, IndexedDB, 서버 API 등으로 영구 저장 미구현 (개발 편의성만 제공)
- **권한 관리**: 운영 환경에서의 접근 제어 미구현 (개발 모드 전용이므로 자동 제한)
- **버전 관리**: 이전 버전 복구, Undo/Redo 미구현
- **포트폴리오 에디터**: 이 스펙은 이력서(`resume.ts`)만 대상. 포트폴리오 에디터는 별도 스펙으로
- **이미지 업로드**: 텍스트 편집만 지원, 이미지 추가/변경 미구현
- **자동 저장**: 수동 "저장" 버튼 클릭만 반영 (자동 저장 미포함)
- **섹션 추가/삭제**: 기존 섹션의 필드 편집만 가능, 새로운 섹션 추가 미구현

---

## 보안 및 운영 고려사항

### XSS 방지
- 모든 입력값을 `.textContent` 또는 Astro 자동 이스케이프를 통해 처리
- 절대 `.innerHTML`에 사용자 입력 직접 할당 금지

### 프로덕션 안전성
- Tree-shaking 확인: `npm run build` 후 `dist/resume/index.html`에서 `editable-section`, `ResumeEditor` 미포함 검증 필수
- 빌드 최적화: `import.meta.env.DEV` 조건 사용으로 불필요한 코드 제거

### 개발 모드 전용 명시
- 콘솔 경고 또는 주석으로 "이 기능은 개발 모드 전용"임을 명시

---

## 참고

- **관련 문서**:
  - `docs/stack.md` — 기술 스택 및 의존성
  - `docs/qa/20260406-portfolio-display-report.md` — 이전 사이클 QA 보고서
  - `docs/spec/20260401-resume-page.md` — 이력서 페이지 초기 구현 스펙

- **Astro 관련 문서**:
  - [Astro Environment Variables](https://docs.astro.build/en/guides/environment-variables/)
  - [Client-side JavaScript in Astro](https://docs.astro.build/en/guides/client-side-scripts/)

- **참고 컴포넌트**:
  - `src/components/ThemeToggle.astro` — 클라이언트 사이드 상태 관리 참고

