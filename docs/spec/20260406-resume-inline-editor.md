# 스펙: 이력서 개발 모드 Inline 편집 에디터 (모달 제거)

- **날짜**: 2026-04-06
- **사이클**: #4
- **작성자**: 기획 에이전트
- **이전 스펙**: `docs/spec/20260406-resume-editor.md` (모달 기반)

---

## 목표

사용자 피드백을 반영하여 **모달 기반 에디터를 Inline 편집 모드로 전환**한다.
- 모달 제거: 클릭 시 모달창 대신 그 위치에서 직접 입력/textarea 표시
- UX 개선: 편집 모드로 전환되면 그 섹션의 컨텐츠가 즉시 입력 필드로 변환
- 저장/취소 버튼: 입력 필드 바로 옆에 작은 버튼으로 표시
- 보안 유지: XSS 방지, 메모리 기반 상태 관리

**배경:** 사용자가 모달 열고 닫는 인터페이스를 불편하게 느껴, 그 자리에서 바로 편집하는 방식 요청.

---

## 주요 변경점 (이전 모달 버전과의 차이)

| 항목 | 이전 (모달) | 변경 (Inline) |
|------|-----------|-------------|
| 편집 UI | `<dialog>` 모달 | 섹션 내부 inline input/textarea |
| 아이콘 클릭 시 | 모달 팝업 | 섹션 전체가 편집 모드로 전환 |
| 필드 표시 위치 | 모달 내부 | 기존 섹션 텍스트 자리에 표시 |
| 저장/취소 버튼 | 모달 하단 | 입력 필드 바로 옆 (컴팩트) |
| 상태 관리 | 메모리 기반 (동일) | 메모리 기반 (동일) |
| 취소 시 동작 | 모달 닫기 + 상태 롤백 | 편집 모드 해제 + 상태 롤백 |

---

## 변경 대상 파일

```
src/pages/resume.astro              — Inline 편집 모드 마크업 추가, 에디터 아이콘 유지
src/components/ResumeEditor.astro   — 모달 제거, Inline 편집 로직으로 재작성
src/data/resume.ts                  — 변경 없음 (데이터 구조 유지)
```

**제거 대상:**
- `src/components/ResumeEditor.astro`의 `<dialog>` 요소 및 모달 스타일
- 모달 오픈/클로즈 이벤트 핸들러

---

## 수용 기준 (Acceptance Criteria)

검증 에이전트가 PASS/FAIL을 판정할 수 있도록 **측정 가능하게** 작성한다.

- [ ] AC-1: `npm run build`가 오류 없이 성공하며, 프로덕션 빌드에 Inline 에디터 UI가 포함되지 않는다 (개발 모드 전용)

- [ ] AC-2: `npm run dev` 후 `/resume` 접속 시, 5개 섹션(Hero, Professional Summary, Professional Experience, Core Technical Stack, Education)에 마우스 호버 시 에디터 아이콘(✏️)이 표시된다 (이전과 동일)

- [ ] AC-3: 에디터 아이콘 클릭 시 모달이 나타나지 않고, 그 섹션이 **편집 모드로 전환**된다:
  - Professional Summary: textarea 표시 (원본 텍스트 로드)
  - Professional Experience: company, period 등 input 필드 표시
  - Core Technical Stack: category, skills 입력 필드 표시
  - Education: school, major, period input 필드 표시
  - Hero: name, title, email, github input 필드 표시

- [ ] AC-4: 편집 모드에서 입력 필드 옆에 **"저장(✓)", "취소(✕)" 버튼이 작게 표시**된다 (또는 인라인 컴팩트 UI)

- [ ] AC-5: "저장" 버튼 클릭 시 페이지의 해당 섹션이 즉시 업데이트되고 편집 모드가 해제된다 (메모리 기반, 모달 없음)

- [ ] AC-6: "취소" 버튼 또는 ESC 키 클릭 시 편집 모드가 해제되고 수정 사항이 반영되지 않는다

- [ ] AC-7: 페이지 새로고침 후 수정 사항은 유지되지 않는다 (localStorage 미사용)

- [ ] AC-8: 프로덕션 환경(built 파일)에서 에디터 UI 및 관련 스크립트가 완전히 제거되어, 빌드 크기가 모달 버전보다 감소한다

- [ ] AC-9: TypeScript 타입 검증 오류가 0개 (`npx tsc --noEmit`)

---

## 테스트 시나리오

### 정상 케이스

#### 테스트 1: 개발 모드 진입 및 에디터 아이콘 표시
1. `npm run dev` 실행
2. 브라우저에서 `http://localhost:4321/resume/` 접속
3. "Professional Summary" 섹션 위에 마우스 호버
4. **예상 결과**: 
   - 에디터 아이콘(✏️) 표시 (AC-2)
   - 아직 편집 모드 아님, 텍스트만 보임

#### 테스트 2: Inline 편집 모드 진입
1. "Professional Summary" 섹션의 에디터 아이콘 클릭
2. **예상 결과**:
   - 모달이 나타나지 않음 (AC-3)
   - 섹션이 편집 모드로 전환: 현재 요약 텍스트가 textarea에 로드됨
   - textarea 옆에 "저장" 및 "취소" 버튼 표시 (AC-4)
   - 타이틀은 그대로 유지 ("Professional Summary")

#### 테스트 3: Inline 편집 및 저장
1. 테스트 2에서 textarea에 입력된 텍스트 일부 수정 (예: 끝에 " (수정됨)" 추가)
2. "저장" 버튼 클릭
3. **예상 결과**:
   - textarea 사라짐
   - 섹션이 정상 모드로 복구
   - 수정된 텍스트가 표시됨 (AC-5)
   - 새로고침 없이 변경사항 유지

#### 테스트 4: Inline 편집 취소
1. "Professional Experience" 섹션의 에디터 아이콘 클릭
2. 편집 모드 진입 (input 필드 표시)
3. 텍스트 수정
4. "취소" 버튼 클릭
5. **예상 결과**:
   - 편집 모드 해제
   - 수정 사항 반영 안 됨 (원본 유지) (AC-6)

#### 테스트 5: ESC 키로 편집 취소
1. 섹션을 편집 모드로 진입
2. ESC 키 누름
3. **예상 결과**:
   - 편집 모드 해제
   - 수정 사항 미반영

#### 테스트 6: 페이지 새로고침 후 상태
1. Professional Summary 섹션 수정 및 저장
2. 브라우저 새로고침 (F5)
3. **예상 결과**:
   - 페이지 로드
   - Professional Summary가 원래 내용으로 복원 (AC-7)

#### 테스트 7: 프로덕션 빌드 검증
1. `npm run build` 실행
2. `dist/resume/index.html` 검사
3. **예상 결과**:
   - HTML에 `data-editable`, `editable-section` 속성 미포함
   - 에디터 관련 스크립트 미포함 (AC-8)

#### 테스트 8: 여러 섹션 연속 편집
1. Professional Summary 수정 및 저장
2. Core Technical Stack 아이콘 클릭 → 편집 모드 진입
3. 필드 수정 후 저장
4. **예상 결과**:
   - 두 섹션 모두 정상 반영
   - 상태 충돌 없음

### 엣지 케이스

#### 테스트 9: 긴 텍스트 입력
1. Professional Summary 편집 모드 진입
2. 현재 텍스트를 3배 길이로 교체
3. "저장" 클릭
4. **예상 결과**:
   - 페이지 레이아웃 깨지지 않음 (오버플로우 처리)
   - 전체 텍스트 표시

#### 테스트 10: 특수문자 및 XSS 시도
1. Professional Summary 편집 모드 진입
2. `<script>alert('xss')</script>`, `&`, `"` 등 특수문자 입력
3. "저장" 클릭
4. **예상 결과**:
   - XSS 공격 미발생
   - 특수문자 정상 렌더링 (이스케이프됨)

#### 테스트 11: 빈 텍스트 입력
1. Professional Summary 편집 모드 진입
2. textarea 텍스트 모두 삭제
3. "저장" 클릭
4. **예상 결과**:
   - 섹션 텍스트 영역 공백 표시
   - 레이아웃 구조 유지

#### 테스트 12: 호버 중에 편집 모드 진입/해제
1. Professional Summary 호버 (아이콘 표시)
2. 아이콘 클릭 (편집 모드 진입)
3. 마우스를 다른 섹션으로 이동
4. **예상 결과**:
   - 편집 모드는 유지됨 (호버 스타일 상관없음)
   - 취소/저장 버튼 계속 표시

---

## 기술 설계

### 아키텍처

#### 1. 개발 모드 감지 (이전과 동일)
```typescript
// resume.astro
const isDev = import.meta.env.DEV;
```

#### 2. 에디터 아이콘 마크업 (이전과 동일)
- 각 섹션에 `editable-section` 클래스 + `data-editor-icon` 속성
- 호버 시 아이콘 표시

#### 3. Inline 편집 모드 구현
**이전 방식 (제거할 것):**
```typescript
// 모달 열기
modal.showModal();
```

**신규 방식 (구현할 것):**
```typescript
// 편집 모드 전환
function enterEditMode(sectionId: string) {
  const section = document.querySelector(`[data-editable="${sectionId}"]`);
  // section 내부의 컨텐츠를 input/textarea로 치환
  // 저장/취소 버튼 추가
  section.classList.add('edit-mode');
}

function exitEditMode(sectionId: string, save: boolean) {
  if (save) {
    // DOM 업데이트
  } else {
    // 상태 롤백
  }
  section.classList.remove('edit-mode');
}
```

#### 4. 클라이언트 사이드 상태 관리 (이전과 동일)
- 메모리 내 상태 (localStorage 미사용)
- 각 섹션의 원본 데이터 보관

#### 5. 스타일링 전략
- **edit-mode 상태**: `data-edit-mode="sectionId"` 속성으로 편집 모드 표시
- **입력 필드**: 섹션 내부에 inline으로 렌더링
- **저장/취소 버튼**: 컴팩트 크기 (32px 정도), 입력 필드 옆 배치
- **모달 스타일 제거**: 모달 관련 CSS 모두 제거

---

## 구현 상세

### resume.astro 변경사항

**이전:**
```astro
{isDev && <ResumeEditor />}  <!-- 모달 컴포넌트 -->
<section data-editable="hero" class="editable-section">
  <!-- 정적 콘텐츠 -->
</section>
```

**신규:**
```astro
{isDev && <ResumeEditor />}  <!-- Inline 에디터 로직 -->
<section 
  data-editable="hero" 
  class="editable-section"
  data-edit-mode="false"  <!-- 편집 모드 상태 플래그 -->
>
  <!-- 정적 콘텐츠 (편집 모드 아닐 때) -->
  <!-- 편집 모드 시 이 자리에 input/textarea가 표시됨 -->
</section>
```

### ResumeEditor.astro 재작성

**제거:**
- `<dialog id="resume-editor-modal">` 전체 제거
- 모달 열기/닫기 이벤트 핸들러
- 모달 스타일 CSS 제거

**신규 추가:**
```typescript
// 편집 모드 전환
function enterEditMode(sectionId: string) {
  // 현재 섹션 데이터를 DOM에서 추출
  // input/textarea 요소 생성 및 삽입
  // 저장/취소 버튼 추가
}

function exitEditMode(sectionId: string, save: boolean) {
  // save=true: 메모리 상태 → DOM 업데이트
  // save=false: 원본 상태로 롤백
  // input/textarea 제거, 원본 텍스트 복구
}
```

**스크립트 로직:**
1. 에디터 아이콘 클릭 → `enterEditMode(sectionId)` 호출
2. "저장" 버튼 클릭 → `updateDOM()` + `exitEditMode(sectionId, true)`
3. "취소" 버튼 또는 ESC 키 → `exitEditMode(sectionId, false)`

### 스타일 (컴팩트)

```css
/* Inline 편집 모드 상태 */
[data-edit-mode="true"] {
  /* 편집 모드일 때 섹션 스타일 */
}

.resume-editor-inline-input,
.resume-editor-inline-textarea {
  /* 인라인 input/textarea 스타일 */
  padding: 0.5rem;
  border: 1px solid var(--color-border);
  border-radius: 0.25rem;
  font-size: 0.875rem;
}

.resume-editor-inline-actions {
  /* 저장/취소 버튼 */
  display: inline-flex;
  gap: 0.25rem;
  margin-left: 0.5rem;
}

.resume-editor-inline-btn {
  /* 버튼: 작고 컴팩트 */
  width: 28px;
  height: 28px;
  padding: 0.25rem;
  font-size: 0.75rem;
}
```

---

## 이전 모달 코드 제거 범위

다음 항목을 명시적으로 **제거해야 함:**

1. **HTML 마크업 제거:**
   - `<dialog id="resume-editor-modal">` 요소 전체
   - 모달 헤더 (`resume-editor-header`), 폼 컨테이너 등

2. **JavaScript 제거:**
   - `modal.showModal()` 호출 구문
   - 모달 열기/닫기 이벤트 핸들러:
     - `closeBtn.addEventListener('click', ...)`
     - `cancelBtn.addEventListener('click', ...)`
     - `modal.addEventListener('click', ...)`
   - 모달 관련 변수: `const modal = ...`, `const closeBtn = ...` 등

3. **CSS 스타일 제거:**
   - `.resume-editor-modal`, `.resume-editor-modal::backdrop`
   - `.resume-editor-content`, `.resume-editor-header`, `.resume-editor-form`
   - `.resume-editor-actions`, `.resume-editor-btn*` 등 모달 버튼 스타일

4. **유지되는 것:**
   - `initializeState()` 함수 (상태 초기화)
   - `updateDOM()` 함수 (DOM 업데이트 로직)
   - `state` 객체 (메모리 기반 상태)
   - 에디터 아이콘 클릭 이벤트 (`data-editor-icon` 핸들러)

---

## 마이그레이션 가이드 (구현자용)

### 1단계: 모달 마크업 제거
- ResumeEditor.astro에서 `<dialog>` 요소 완전 제거

### 2단계: Inline 편집 UI 구현
- `enterEditMode(sectionId)` 함수 구현
  - 해당 섹션의 콘텐츠를 input/textarea로 치환
  - 저장/취소 버튼 추가
  
### 3단계: 저장/취소 핸들러 구현
- "저장" 클릭 → `updateDOM()` + `exitEditMode(true)`
- "취소" 클릭 또는 ESC → `exitEditMode(false)`

### 4단계: 스타일 업데이트
- 모달 CSS 제거
- Inline 편집 모드 스타일 추가 (컴팩트)

### 5단계: 테스트
- AC-1 ~ AC-9 모두 검증
- 회귀 테스트 (다른 페이지 영향 없음 확인)

---

## 이번 사이클에서 하지 않는 것

- **데이터 저장**: localStorage, 서버 API 미사용 (개발 모드만)
- **권한 관리**: 개발 모드 전용이므로 자동 제한
- **버전 관리**: Undo/Redo 미구현
- **포트폴리오 에디터**: 별도 스펙으로 진행
- **이미지 업로드**: 텍스트 편집만 지원

---

## 보안 및 운영

### XSS 방지
- 모든 입력값을 `.textContent` 사용 (`.innerHTML` 절대 금지)
- Astro 자동 이스케이프 활용

### 프로덕션 안전성
- Tree-shaking 확인 필수: `npm run build` 후 에디터 코드 미포함 검증
- 빌드 크기 감소 확인: 모달 제거로 인한 크기 축소

### 개발 모드 전용
- `import.meta.env.DEV` 가드 유지
- 콘솔 로그에 "dev mode only" 명시

---

## 참고

**관련 문서:**
- 이전 모달 스펙: `docs/spec/20260406-resume-editor.md`
- 이전 모달 QA 보고서: `docs/qa/20260406-resume-editor-report.md`
- 이력서 페이지: `src/pages/resume.astro`
- 에디터 컴포넌트: `src/components/ResumeEditor.astro`

**변경 전 커밋:** `72f9130` (모달 기반 에디터)

