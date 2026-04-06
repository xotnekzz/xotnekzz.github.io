# 스펙: 이력서 더블클릭 편집 후 resume.ts 파일 저장 수정

- **날짜**: 2026-04-06
- **사이클**: #5
- **작성자**: 기획 에이전트

---

## 목표

`/resume` 페이지에서 텍스트를 더블클릭하여 수정한 뒤, "파일에 저장" 버튼을 클릭하면 `src/data/resume.ts`가 실제로 업데이트되어야 한다. 현재는 POST `/api/save-resume` 호출이 정상 응답하지 않거나, 파일 경로 해석 오류로 인해 파일이 수정되지 않는 문제가 있다.

**배경:** 사용자 직접 보고 — 더블클릭 편집 후 "파일에 저장" 버튼을 눌러도 `src/data/resume.ts`가 변경되지 않음. 최근 커밋 이력(`5dff87a fix: API 에러 처리 개선 및 디버깅 로깅 추가`)에서 에러 처리를 개선했음에도 근본 원인이 해결되지 않은 상태.

---

## 핵심 기술 결정

### 문제 원인 분석

#### 원인 1: `import.meta.url` 경로 오류 (고확률)

`src/pages/api/save-resume.ts`의 최상위 레벨에서 실행되는 코드:

```typescript
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PROJECT_ROOT = resolve(__dirname, '../../../');
```

Vite dev server 환경에서 `import.meta.url`은 실제 디스크 경로 대신 Vite가 변환한 가상 경로(`/@fs/...` 또는 `file:///...`)를 반환할 수 있다. 결과적으로 `PROJECT_ROOT`가 잘못 계산되어 `RESUME_FILE` 경로가 존재하지 않는 위치를 가리키게 된다.

#### 원인 2: Astro 정적 모드에서의 API 라우트 불안정성

`astro.config.mjs`에 `output` 설정이 없으므로 Astro 기본값은 `static`이다. `static` 모드에서 `src/pages/api/save-resume.ts`의 POST 핸들러는 개발 서버(`npm run dev`)에서는 동작하나, Vite 내부 변환 파이프라인을 거치면서 모듈 레벨 `fileURLToPath` 호출이 예측과 다른 경로를 반환할 수 있다.

#### 원인 3: 편집 데이터 키 형식과 파일 저장 로직의 불일치

`ResumeEditor.astro`의 `saveEditToStorage`는 `fieldIdentifier`를 키로 사용한다. 이 값은 `fieldPath`가 결정되지 않은 경우 `"tagname|텍스트앞30글자"` 형태의 fallback 값이 저장된다. `save-resume.ts`는 `"personal.name"`, `"summary"` 등 명확한 경로만 처리하므로, fallback 키는 아무 처리도 하지 않고 `console.log('Unsupported field: ...')`만 남긴다.

### 해결 방향: Vite dev server middleware로 교체

Astro API 라우트 대신 `astro.config.mjs`의 `vite.plugins`에 커스텀 Vite 플러그인(dev server middleware)을 등록한다.

**Vite 미들웨어 방식의 이점:**
- `process.cwd()`로 프로젝트 루트를 확실하게 얻을 수 있어 경로 오류가 없다
- 빌드 시 플러그인의 `configureServer` 훅은 실행되지 않으므로 프로덕션 빌드에 영향 없음
- Node.js 네이티브 `fs` 모듈을 직접 사용하므로 Vite 변환 파이프라인을 거치지 않는다
- `src/pages/api/save-resume.ts` 파일을 삭제하면 `static` 모드 빌드에서 불필요한 HTML 생성 시도를 방지한다

```javascript
// astro.config.mjs 추가 예시
function resumeSavePlugin() {
  return {
    name: 'resume-save-plugin',
    configureServer(server) {
      server.middlewares.use('/api/save-resume', async (req, res) => {
        if (req.method !== 'POST') { res.statusCode = 405; res.end(); return; }
        // process.cwd() 기반 경로 사용
        const resumeFile = path.resolve(process.cwd(), 'src/data/resume.ts');
        // ... 파일 읽기/수정/쓰기
      });
    },
  };
}
```

---

## 변경 대상 파일

```
astro.config.mjs                  — Vite dev middleware 플러그인 추가 (resumeSavePlugin)
src/pages/api/save-resume.ts      — 삭제 또는 미사용 표시 (Vite 미들웨어로 기능 이전)
src/components/ResumeEditor.astro — fieldPath 누락 시 파일 저장 스킵 로직 추가 (옵션)
```

---

## 수용 기준 (Acceptance Criteria)

| ID | 기준 | 판정 방법 |
|----|------|-----------|
| AC-1 | `npm run build`가 오류 없이 성공한다 | 빌드 실행 후 exit code 0, 오류 메시지 없음 |
| AC-2 | `npm run dev` 실행 후 `POST http://localhost:4321/api/save-resume`에 `{"edits":{"personal.name":"테스트"}}` 요청 시 HTTP 200 응답과 `{"success":true}` JSON 반환 | `curl -X POST -H 'Content-Type: application/json' -d '{"edits":{"personal.name":"테스트"}}' http://localhost:4321/api/save-resume` |
| AC-3 | AC-2 요청 후 `src/data/resume.ts` 파일을 읽으면 `name: '테스트'`로 변경되어 있다 | `grep "name: '테스트'" src/data/resume.ts` 결과 1줄 이상 |
| AC-4 | `/resume` 페이지에서 이름 텍스트를 더블클릭 → 수정 → 포커스 해제 → "파일에 저장" 버튼 클릭 시 성공 알림(`✅`)이 표시된다 | 브라우저 수동 테스트 또는 개발 서버 로그 확인 |
| AC-5 | `personal.name`, `personal.title`, `personal.email`, `personal.github`, `summary` 5개 필드 모두 저장 후 파일 반영이 확인된다 | 각 필드별 `curl` POST 후 `grep` 확인 |
| AC-6 | `src/pages/api/save-resume.ts`가 삭제된 경우, `npm run build` 시 해당 파일 관련 오류가 없고 `dist/api/` 디렉터리가 생성되지 않는다 | `ls dist/api/ 2>&1` 결과 `No such file or directory` |
| AC-7 | 지원하지 않는 fieldPath(예: fallback 형태 `"span|텍스트"`)가 포함된 요청은 무시되고 나머지 지원 필드만 저장된다 | 혼합 요청 후 로그 확인, 파일 내용 검증 |
| AC-8 | 프로덕션 빌드 `dist/resume/index.html`에 `resume-editor`, `data-editor-icon` 관련 코드가 없다 | `grep -c "resume-editor\|data-editor-icon" dist/resume/index.html` → 0 |

---

## 테스트 시나리오

### 정상 케이스

1. **단일 필드 저장**
   - 입력: `{"edits": {"personal.name": "홍길동"}}`
   - 예상: HTTP 200, `src/data/resume.ts`의 `name: '홍길동'`으로 변경

2. **여러 필드 동시 저장**
   - 입력: `{"edits": {"personal.name": "홍길동", "summary": "새 요약문"}}`
   - 예상: HTTP 200, 두 필드 모두 파일에 반영

3. **summary 필드 저장 (여러 줄 연결 문자열)**
   - 입력: `{"edits": {"summary": "단일 줄 요약"}}`
   - 예상: `export const summary =\n  '단일 줄 요약';` 형태로 저장

4. **UI 흐름 전체**
   - `/resume` 더블클릭 → 이름 수정 → 포커스 해제 → localStorage에 저장됨 확인 → "파일에 저장" 버튼 클릭 → 성공 알림 → 페이지 새로고침 → 변경된 이름 표시

### 엣지 케이스

1. **작은따옴표 포함 텍스트**
   - 입력: `{"edits": {"personal.name": "O'Brien"}}`
   - 예상: `name: 'O\'Brien'`으로 이스케이프 처리되어 파일에 저장, 파일이 유효한 TypeScript

2. **빈 edits 객체**
   - 입력: `{"edits": {}}`
   - 예상: HTTP 200, `edits: 0` 반환, 파일 미변경

3. **지원하지 않는 fieldPath만 포함**
   - 입력: `{"edits": {"span|텍스트": "값"}}`
   - 예상: HTTP 200, `edits: 0` 또는 무시 메시지, 파일 미변경

4. **잘못된 JSON 요청**
   - 입력: 빈 body 또는 `{invalid json}`
   - 예상: HTTP 400, `{"error": "Invalid JSON"}` 반환

5. **프로덕션 빌드 환경에서 API 호출 시도**
   - 예상: Vite 미들웨어는 dev 서버에서만 동작하므로 프로덕션에서는 엔드포인트 자체가 없음 (의도된 동작)

---

## 이번 사이클에서 하지 않는 것

- `experience`, `techstack`, `education` 섹션의 배열 항목 파일 저장 지원 (복잡한 배열 인덱스 처리 필요, 별도 사이클)
- 저장 후 Undo/Redo 기능
- 편집 UI 자체의 변경 (아이콘 방식 vs 더블클릭 방식 논쟁 — 현재 더블클릭 방식 유지)
- 프로덕션 배포 환경에서의 파일 저장 기능 (정적 사이트 특성상 불필요)
- `resume.ts` 파싱 방식을 AST 기반으로 변경 (정규식 기반 유지)
- 저장 시 Git 커밋 자동화

---

## 구현 가이드 (개발 에이전트 참고)

### astro.config.mjs 수정 예시

```javascript
// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';
import { writeFileSync, readFileSync, existsSync } from 'fs';
import { resolve } from 'path';

function resumeSavePlugin() {
  return {
    name: 'vite-plugin-resume-save',
    configureServer(server) {
      server.middlewares.use('/api/save-resume', async (req, res) => {
        if (req.method !== 'POST') {
          res.statusCode = 405;
          res.end(JSON.stringify({ error: 'Method Not Allowed' }));
          return;
        }

        const RESUME_FILE = resolve(process.cwd(), 'src/data/resume.ts');

        let body = '';
        req.on('data', (chunk) => { body += chunk; });
        req.on('end', () => {
          try {
            const { edits } = JSON.parse(body);
            if (!edits || typeof edits !== 'object') {
              res.statusCode = 400;
              res.setHeader('Content-Type', 'application/json');
              res.end(JSON.stringify({ error: 'Invalid edits data' }));
              return;
            }

            if (!existsSync(RESUME_FILE)) {
              res.statusCode = 500;
              res.setHeader('Content-Type', 'application/json');
              res.end(JSON.stringify({ error: 'resume.ts not found', path: RESUME_FILE }));
              return;
            }

            let content = readFileSync(RESUME_FILE, 'utf-8');
            let savedCount = 0;

            Object.entries(edits).forEach(([field, value]) => {
              const v = (value as string).replace(/'/g, "\\'");
              if (field === 'personal.name') {
                content = content.replace(/(\s*name:\s*')[^']*'/, `$1${v}'`);
                savedCount++;
              } else if (field === 'personal.title') {
                content = content.replace(/(\s*title:\s*')[^']*'/, `$1${v}'`);
                savedCount++;
              } else if (field === 'personal.email') {
                content = content.replace(/(\s*email:\s*')[^']*'/, `$1${v}'`);
                savedCount++;
              } else if (field === 'personal.github') {
                content = content.replace(/(\s*github:\s*')[^']*'/, `$1${v}'`);
                savedCount++;
              } else if (field === 'summary') {
                const escaped = (value as string).replace(/\n/g, ' ').replace(/'/g, "\\'");
                content = content.replace(
                  /export const summary\s*=[\s\S]*?;/,
                  `export const summary =\n  '${escaped}';`,
                );
                savedCount++;
              }
            });

            writeFileSync(RESUME_FILE, content, 'utf-8');
            res.statusCode = 200;
            res.setHeader('Content-Type', 'application/json');
            res.end(JSON.stringify({ success: true, edits: savedCount, savedTo: RESUME_FILE }));
          } catch (err) {
            res.statusCode = 500;
            res.setHeader('Content-Type', 'application/json');
            res.end(JSON.stringify({ error: String(err) }));
          }
        });
      });
    },
  };
}

export default defineConfig({
  site: 'https://xotnekzz.github.io',
  vite: { plugins: [tailwindcss(), resumeSavePlugin()] },
  integrations: [
    sitemap({
      filter: (page) => page !== 'https://xotnekzz.github.io/portfolio/',
    }),
  ],
  markdown: {
    shikiConfig: { theme: 'github-dark' },
  },
});
```

### src/pages/api/save-resume.ts 처리

Vite 미들웨어로 기능이 이전된 후 이 파일은 역할이 없다. 삭제를 권장하지만, 삭제 시 Git 이력 보존을 위해 파일 내용을 `export const prerender = false;` 한 줄만 남기는 방식도 허용한다. 단, `static` 모드에서 POST 핸들러가 없는 빈 API 파일이 빌드 오류를 일으키지 않는지 확인 후 결정한다.

---

## 보안 고려사항

- Vite 미들웨어의 `configureServer` 훅은 **개발 서버에서만 실행**된다 (`npm run build` 시 해당 훅이 호출되지 않음). 프로덕션 빌드 결과물에 파일 쓰기 코드가 포함되지 않는다.
- `process.cwd()`는 프로젝트 루트를 반환하므로 경로 탈출(`../../../etc/passwd` 등) 공격이 가능하다. 이번 사이클은 개발 도구이므로 별도 경로 검증은 생략하되, 저장 대상을 `src/data/resume.ts` 고정 경로로 하드코딩하여 위험을 최소화한다.

---

## 참고

- 관련 파일: `src/components/ResumeEditor.astro`, `src/pages/api/save-resume.ts`, `src/data/resume.ts`
- 관련 스펙: `docs/spec/20260406-resume-inline-editor.md`
- QA 보고서: `docs/qa/20260406-resume-inline-editor-report.md`
- Vite configureServer API: https://vite.dev/guide/api-plugin#configureserver
