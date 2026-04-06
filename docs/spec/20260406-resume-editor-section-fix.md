# 스펙: 이력서 에디터 섹션 H2 편집 불가 처리 및 fieldPath 버그 수정

- **날짜**: 2026-04-06
- **사이클**: #6
- **작성자**: 기획 에이전트

---

## 목표

`/resume` 페이지의 더블클릭 에디터에서 섹션 H2 제목을 더블클릭할 경우 해당 섹션의 내용(paragraph 등)이 H2 텍스트로 덮어쓰이는 버그를 수정한다. H2 섹션 제목은 `resume.ts`에 대응하는 필드가 없는 UI 레이블이므로 편집 불가 처리하는 것이 올바른 해결 방법이다.

**배경:** QA 보고서 `docs/qa/20260406-resume-file-save-report.md`에서 발견된 버그. `startEditing()` 함수의 `fieldPath` 감지 로직이 더블클릭 대상 요소가 H2 자신인지 확인하지 않고 "부모 섹션의 h2가 특정 텍스트를 포함하는가"만 검사한다. 그 결과 H2를 더블클릭해도 `fieldPath = 'summary'` 등으로 설정되어 H2 텍스트가 해당 필드 값으로 저장됨.

---

## 변경 대상 파일

```
src/components/ResumeEditor.astro  — dblclick 핸들러에 H2 early return 추가, H2 CSS 호버 효과 제거
```

`src/pages/resume.astro` 및 `src/data/resume.ts`는 변경하지 않는다.

---

## 수용 기준 (Acceptance Criteria)

검증 에이전트가 PASS/FAIL을 판정할 수 있도록 측정 가능하게 작성한다.

- [ ] AC-1: `npm run build`가 오류 없이 성공한다
- [ ] AC-2: `src/components/ResumeEditor.astro`의 `dblclick` 이벤트 핸들러 내에 `target.tagName === 'H2'`이면 편집을 시작하지 않고 즉시 반환(early return)하는 코드가 존재한다. `grep -n "H2" src/components/ResumeEditor.astro`로 해당 가드 구문 확인.
- [ ] AC-3: Professional Summary 섹션의 `<p>` 요소 처리 코드에서 `element.tagName === 'H2'` 조건을 통과한 이후에만 `fieldPath = 'summary'`가 설정된다. 즉, H2 early return 이후에 위치하거나, `else if` 조건에 `element.tagName !== 'H2'` 보호가 추가된 형태여야 한다.
- [ ] AC-4: `src/components/ResumeEditor.astro`의 `<style>` 블록에서 `.editable-section h2`에 대해 `cursor: default`와 `background-color` 호버 효과가 명시적으로 재정의되어 `.editable-section *:hover` 규칙을 무효화한다. `grep -A3 "editable-section h2" src/components/ResumeEditor.astro`로 해당 CSS 확인.
- [ ] AC-5: `npx tsc --noEmit`이 오류 없이 완료된다

---

## 테스트 시나리오

### 정상 케이스

1. **H2 더블클릭 무시**: `/resume` 페이지 개발 서버(`npm run dev`)에서 "Professional Summary" H2 요소를 더블클릭 → 인라인 입력 필드가 나타나지 않아야 한다. 다른 섹션 H2("Professional Experience", "Core Technical Stack", "Education")도 동일하게 편집 불가.

2. **Summary 단락 편집 정상 작동**: Professional Summary 섹션의 `<p>` 요소 더블클릭 → 인라인 textarea가 나타나고, 수정 후 "파일에 저장" 클릭 시 `summary` 필드로 올바르게 저장된다.

3. **Hero 섹션 필드 편집 유지**: H1(이름), title `<p>`, 이메일/GitHub 링크는 기존과 동일하게 편집 가능해야 한다.

### 엣지 케이스

1. **Hero 섹션에는 H2 없음**: Hero 섹션(`.editable-section` 첫 번째 섹션)은 H2가 없으므로 early return 로직이 영향을 주지 않아야 한다.

2. **H2 자식 요소 클릭**: H2 내부에 `<span>` 등이 중첩된 경우, `target.tagName`이 `SPAN`이더라도 `target.closest('h2')`를 통해 편집 불가 처리가 적용되어야 한다. (구현 시 `closest('h2')` 체크를 권장함)

3. **기존 localStorage 편집사항 복원**: 페이지 새로고침 후 `restoreSavedEdits()`가 H2 관련 selector를 시도해도 오류 없이 무시되어야 한다.

---

## 구현 가이드

### early return 추가 위치

`document.addEventListener('dblclick', ...)` 핸들러 내부, `editableSection` 확인 직후에 추가:

```javascript
// H2 섹션 제목은 resume.ts에 대응 필드 없음 → 편집 불가
if (target.tagName === 'H2' || target.closest('h2')) return;
```

### CSS 변경

기존 `.editable-section *:hover:not(a):not(button)` 규칙에 `h2`를 추가하거나, 별도 규칙으로 H2 호버 효과를 재정의한다:

```css
.editable-section h2 {
  cursor: default;
}

.editable-section h2:hover {
  background-color: transparent;
}
```

---

## 이번 사이클에서 하지 않는 것

- `experience`, `techstack`, `education` 배열 항목(`H3`, `SPAN`, `LI` 등)의 파일 저장 로직 구현
- `resume.ts`의 섹션 H2 텍스트를 동적 데이터로 전환 (하드코딩 유지)
- `src/pages/resume.astro` 템플릿 구조 변경
- 브라우저 자동화(Playwright) 테스트 추가
- 작은따옴표 이스케이프 처리 정규식 개선 (별도 사이클)
- Hero 섹션 이외의 새 편집 필드 추가

---

## 참고

- 관련 QA 보고서: `docs/qa/20260406-resume-file-save-report.md`
- 이전 스펙: `docs/spec/20260406-resume-file-save-fix.md`
- 변경 대상 컴포넌트: `src/components/ResumeEditor.astro`
- 데이터 파일(변경 없음): `src/data/resume.ts`
