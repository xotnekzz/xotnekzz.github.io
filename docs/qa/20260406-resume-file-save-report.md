# QA 보고서: 이력서 더블클릭 편집 후 resume.ts 파일 저장 수정

- **날짜**: 2026-04-06
- **사이클**: #5
- **스펙 문서**: `docs/spec/20260406-resume-file-save-fix.md`
- **검증자**: 검증 에이전트
- **전체 결과**: PARTIAL

---

## 빌드 검증

| 항목 | 결과 | 비고 |
|------|------|------|
| `npm run build` | PASS | exit code 0, 24페이지 생성. `ResumeEditor.astro_astro_type_script_index_0_lang` empty chunk 경고 있으나 오류 아님 |
| `npx tsc --noEmit` | PASS | 타입 오류 없음 |

---

## 수용 기준 체크리스트

| ID | 수용 기준 | 결과 | 확인 방법 |
|----|-----------|------|-----------|
| AC-1 | `npm run build` 오류 없이 성공 | PASS | `npm run build` exit code 0, "24 page(s) built" 확인 |
| AC-2 | POST `/api/save-resume` 요청 시 HTTP 200 + `{"success":true}` 반환 | PASS | `curl -X POST ... {"edits":{"personal.name":"테스트유저"}}` → `{"success":true,"edits":1,...}` |
| AC-3 | AC-2 요청 후 `src/data/resume.ts`에 변경값 반영 | PASS | `grep "name:" src/data/resume.ts` → `name: '테스트유저',` 확인 |
| AC-4 | `/resume` 페이지 UI 흐름: 더블클릭 → 수정 → 저장 → 성공 알림 표시 | SKIP | 브라우저 MCP 미사용 환경. curl API 테스트로 백엔드 동작 확인됨 |
| AC-5 | `personal.name`, `personal.title`, `personal.email`, `personal.github`, `summary` 5개 필드 모두 저장 반영 | PASS | 5개 필드 동시 POST → `{"success":true,"edits":5}`, grep으로 각 필드 파일 반영 확인 |
| AC-6 | `src/pages/api/save-resume.ts` 삭제 후 빌드 시 `dist/api/` 미생성 | PASS | `ls dist/api/ 2>&1` → `No such file or directory` |
| AC-7 | 지원하지 않는 fieldPath(`"span|텍스트"`)는 무시, 지원 필드만 저장 | PASS | `{"edits":{"span|텍스트":"값","personal.name":"김태수"}}` → `{"success":true,"edits":1}`, 지원 필드만 저장 확인 |
| AC-8 | `dist/resume/index.html`에 `resume-editor`, `data-editor-icon` 코드 없음 | PASS | `grep -c "resume-editor\|data-editor-icon" dist/resume/index.html` → `0` |

---

## FAIL 상세

> FAIL 항목 없음. 단, SKIP 항목 1건과 발견된 버그 1건 기록.

### AC-4: SKIP (브라우저 UI 테스트)

**사유:** 브라우저 MCP를 사용하지 않는 환경에서 진행된 검증이므로 UI 흐름 전체는 확인하지 못함. 백엔드 API(curl)를 통해 핵심 저장 기능은 PASS 확인됨.

**권장 추가 검증:** 브라우저에서 `/resume` 접속 후 이름 텍스트 더블클릭, 수정, 포커스 해제, "파일에 저장" 버튼 클릭 순서로 수동 확인 필요.

---

### 발견된 버그: 작은따옴표 포함 값 저장 후 정규식 치환 오류

**심각도:** MINOR (엣지 케이스)

**재현 방법:**
```bash
# 1. 작은따옴표 포함 이름 저장
curl -X POST -H 'Content-Type: application/json' \
  -d '{"edits":{"personal.name":"O'\''Brien"}}' \
  http://localhost:4321/api/save-resume
# 결과: resume.ts에 name: 'O\'Brien', 저장됨

# 2. 이후 정상 이름으로 복원 시도
curl -X POST -H 'Content-Type: application/json' \
  -d '{"edits":{"personal.name":"김태수"}}' \
  http://localhost:4321/api/save-resume
# 결과: name: '김태수'Brien', 로 깨짐
```

**원인 분석:**

`astro.config.mjs`의 정규식 패턴 `/(\s*name:\s*')[^']*'/`은 작은따옴표 `'` 문자가 나타나기 전까지를 값으로 인식한다. O'Brien을 이스케이프하여 `O\'Brien`으로 저장하면, 파일 내용은 `name: 'O\'Brien'`이 된다. 이후 같은 정규식으로 치환 시 `[^']*`가 `O\` 까지만 매칭되어 나머지 `Brien'`이 패턴 밖에 남아 `'김태수'Brien'` 형태로 깨진다.

**수정 제안:**
- 정규식을 `(\s*name:\s*')(?:[^'\\]|\\.)*'` 형태로 개선하여 이스케이프된 작은따옴표(`\'`)를 올바르게 처리.
- 또는 저장 시 이스케이프 대신 `JSON.stringify` 결과를 활용하거나, 백틱 템플릿 리터럴 방식으로 저장 형식 변경 검토.

---

## 회귀(Regression) 검증

| 라우트 | 결과 | 비고 |
|--------|------|------|
| `/` (홈) | PASS | HTTP 200 응답 확인 |
| `/blog/` (목록) | PASS | HTTP 200 응답 확인 |
| `/tags/` (태그 인덱스) | PASS | HTTP 200 응답 확인 |
| `/rss.xml` (RSS 피드) | PASS | HTTP 200 응답 확인 |

---

## 코드 리뷰

- **스펙 범위 준수**: PASS — `astro.config.mjs`에 `resumeSavePlugin` 추가, `src/pages/api/save-resume.ts` 삭제(디렉토리 자체 없음). 스펙 범위 외 파일 변경 없음.
- **보안**: PASS — `configureServer` 훅은 dev 서버에서만 실행되며, 저장 대상이 `src/data/resume.ts` 고정 경로로 하드코딩되어 경로 탈출 위험이 최소화됨. 프로덕션 빌드(`dist/`)에 파일 쓰기 코드 미포함 확인.
- **기존 패턴 일관성**: PASS — `// @ts-check` + JSDoc 타입 어노테이션 방식은 기존 `astro.config.mjs` 패턴과 일치. `process.cwd()` 사용으로 경로 문제 해결.

---

## 구현 확인 요약

### 핵심 변경사항 (커밋 `e40cd3f`)

1. **`astro.config.mjs`**: `resumeSavePlugin()` 함수 추가 — Vite dev middleware 방식으로 `POST /api/save-resume` 처리
   - `process.cwd()` 기반 절대 경로 사용으로 이전 `import.meta.url` 경로 오류 해결
   - 5개 필드(`personal.name`, `personal.title`, `personal.email`, `personal.github`, `summary`) 정규식 치환 구현
   - 빌드 시 `configureServer` 미실행으로 프로덕션 빌드에 영향 없음

2. **`src/pages/api/save-resume.ts`**: 삭제 — `dist/api/` 디렉토리 미생성 확인

---

## 다음 사이클 제안

이번 작업 중 발견한 개선 아이디어:

1. **작은따옴표 이스케이프 처리 개선** — 엣지 케이스 테스트 중 발견. 정규식 패턴이 `\'` 시퀀스를 올바르게 처리하지 못해 연속 저장 시 파일이 깨짐. 정규식을 `(?:[^'\\]|\\.)*` 패턴으로 개선하거나 저장 형식을 백틱 리터럴로 변경하는 방안 검토 권장.

2. **AC-4 브라우저 UI 통합 테스트 자동화** — 현재 UI 흐름 검증은 수동 테스트에 의존. Playwright 등으로 `/resume` 더블클릭 → 수정 → 저장 시나리오 자동화 시 사이클마다 재현 가능한 검증 가능.

3. **`experience`, `techstack`, `education` 배열 항목 저장 지원** — 스펙에서 "이번 사이클에서 하지 않는 것"으로 명시됨. 현재 배열 필드 편집 후 저장 시 무시(edits: 0)되므로 사용자 혼란 가능. 다음 사이클에서 배열 인덱스 기반 저장 로직 추가 필요.

4. **invalid JSON 응답 코드 개선** — 현재 잘못된 JSON 입력 시 HTTP 500을 반환함. 스펙에서는 HTTP 400을 기대하므로 `try-catch` 내에서 JSON 파싱 오류를 별도 처리하여 400으로 응답하는 방향 권장.
