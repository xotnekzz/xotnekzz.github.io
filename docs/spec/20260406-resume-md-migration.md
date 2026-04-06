# 스펙: 이력서 에디터 제거 및 resume.md 파일 전환

- **날짜**: 2026-04-06
- **사이클**: 현재 사이클
- **작성자**: 기획 에이전트

---

## 목표

`/resume` 페이지의 더블클릭 인라인 편집 기능과 관련 서버 미들웨어를 완전히 제거하고,
`src/data/resume.ts` TypeScript 파일을 `src/data/resume.md` (YAML frontmatter + Markdown body) 파일로 전환한다.
이를 통해 사용자가 텍스트 에디터로 직접 이력서 내용을 수정할 수 있게 하고, 코드베이스의 복잡성을 낮춘다.

**배경:** 더블클릭 에디터 구현(ResumeEditor.astro, resumeSavePlugin)은 개발 모드 전용으로 동작하지만
코드 복잡도를 높이고 Vite 미들웨어 의존성을 만든다. 이력서 데이터를 Markdown + YAML frontmatter로
관리하면 코드 편집 없이 텍스트 에디터로 직접 수정이 가능하다.

---

## 변경 대상 파일

```
src/components/ResumeEditor.astro       — 삭제 (더블클릭 에디터 컴포넌트 전체 제거)
astro.config.mjs                        — resumeSavePlugin 함수 및 관련 import(writeFileSync, readFileSync, existsSync, resolve) 제거, vite.plugins에서 resumeSavePlugin() 호출 제거
src/pages/resume.astro                  — ResumeEditor import 제거, isDev 변수 제거, editable-section 조건부 클래스 제거, resume.ts import를 gray-matter 파싱으로 교체
src/data/resume.ts                      — 삭제 (resume.md로 대체)
src/data/resume.md                      — 신규 생성 (resume.ts 데이터를 YAML frontmatter + Markdown body로 이전)
package.json                            — gray-matter 의존성 추가 (현재 미포함 확인됨)
```

---

## resume.md 파일 구조

YAML frontmatter에 구조화 데이터(personal, experiences, techStack, education)를 담고,
Markdown body에 summary 텍스트를 작성한다.

```markdown
---
personal:
  name: 김태수
  title: Senior Data Engineer
  email: xotnekzz@gmail.com
  github: github.com/xotnekzz
  githubUrl: https://github.com/xotnekzz

experiences:
  - company: 비트망고
    companyEn: BitMango
    period: "2019.08 ~ 현재 (7년 차)"
    role: Senior Data Engineer
    projects:
      - title: "[Modernization] ..."
        period: "2025 ~ 현재"
        problem: "..."
        bullets:
          - "..."
        accent: true

techStack:
  - category: Languages
    skills: [Python, SQL, Java, TypeScript, Bash]

education:
  - school: 성공회대학교
    major: 컴퓨터공학과
    period: "2012.02 ~ 2017.02 (졸업)"
---

30억 건 규모의 마케팅 데이터 마트와 수백억 건의 게임 로그 인프라를 StarRocks 및 Doris 기반으로 현대화하여...
```

---

## resume.astro 파싱 방법

Astro 빌드 시 Node.js 컨텍스트에서 실행되므로 `fs.readFileSync` + `gray-matter`를 사용한다.

```typescript
// src/pages/resume.astro frontmatter
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import matter from 'gray-matter';

const resumePath = resolve(process.cwd(), 'src/data/resume.md');
const raw = readFileSync(resumePath, 'utf-8');
const { data, content: summaryBody } = matter(raw);

const { personal, experiences, techStack, education } = data;
const summary = summaryBody.trim();
```

---

## 수용 기준 (Acceptance Criteria)

검증 에이전트가 PASS/FAIL을 판정할 수 있도록 측정 가능하게 작성한다.

- [ ] AC-1: `npm run build`가 오류 없이 성공한다
- [ ] AC-2: `dist/resume/index.html` 파일 내에 문자열 `editable-section`, `data-editor-icon`, `resume-editor`가 존재하지 않는다
- [ ] AC-3: `src/components/ResumeEditor.astro` 파일이 존재하지 않는다
- [ ] AC-4: `src/data/resume.ts` 파일이 존재하지 않는다
- [ ] AC-5: `src/data/resume.md` 파일이 존재한다
- [ ] AC-6: `dist/resume/index.html` 파일 내에 `김태수`와 `Senior Data Engineer` 문자열이 존재한다
- [ ] AC-7: `npx tsc --noEmit`이 오류 없이 성공한다
- [ ] AC-8: `astro.config.mjs` 내에 `resumeSavePlugin` 문자열이 존재하지 않는다

---

## 테스트 시나리오

### 정상 케이스

- `npm run build` 실행 후 `dist/resume/index.html` 생성 확인
- 빌드된 HTML에서 `김태수`, `Senior Data Engineer`, `비트망고`, `BitMango` 텍스트가 렌더링됨
- `resume.md`의 summary body 텍스트가 `dist/resume/index.html`의 `<p>` 태그 내에 존재함
- `resume.md`의 techStack 항목(`Python`, `Apache Doris` 등)이 렌더링됨
- `resume.md`의 education 항목(`성공회대학교`, `컴퓨터공학과`)이 렌더링됨

### 엣지 케이스

- `resume.md` frontmatter의 YAML에 특수문자(한글, 대괄호 포함 프로젝트 제목 등)가 포함된 경우 파싱 오류 없이 빌드됨
  - 예: `title: "[Modernization] 전사 대규모 로그 플랫폼 & OLAP 현대화"` — 큰따옴표로 감싸야 YAML 파싱 안전
- summary body가 여러 줄인 경우 `trim()` 후 단일 문자열로 정상 처리됨
- `npm run dev` 실행 시 더블클릭 편집 아이콘/효과가 나타나지 않음 (editable-section 클래스 없음)

---

## 이번 사이클에서 하지 않는 것

- `resume.md` 파일의 frontmatter 구조 변경 (현재 resume.ts와 동일한 데이터 구조 유지)
- resume 페이지 레이아웃 또는 디자인 변경
- 다른 페이지(`index.astro`, 블로그 포스트 등) 수정
- Notion CMS 연동 또는 resume 데이터를 Notion에서 가져오는 기능
- resume.md를 Astro Content Collections로 관리하는 방식 전환
- 빌드 후 자동 배포(GitHub Pages) 관련 작업

---

## 현재 구현 현황 (파악된 내용)

### 제거 대상 코드 목록

**`astro.config.mjs`에서 제거할 항목:**
- 상단 import: `writeFileSync`, `readFileSync`, `existsSync` (fs), `resolve` (path)
- `resumeSavePlugin()` 함수 전체 (8~81번 라인)
- `vite.plugins` 배열에서 `resumeSavePlugin()` 호출 제거 → `[tailwindcss()]`만 남김

**`src/pages/resume.astro`에서 제거/변경할 항목:**
- `import ResumeEditor from '../components/ResumeEditor.astro';` 제거
- `import { personal, summary, experiences, techStack, education } from '../data/resume';` 제거 후 gray-matter 파싱으로 교체
- `const isDev = import.meta.env.DEV;` 제거
- `{isDev && <ResumeEditor />}` 제거
- 각 `<section>`의 `class={isDev ? '... editable-section' : '...'}` → 단순 정적 클래스로 변경

### 신규 의존성

- `gray-matter`: package.json `dependencies`에 추가 필요 (현재 미포함)
  - `npm install gray-matter` 실행 필요
  - `docs/stack.md` 업데이트 권장

---

## 참고

- 관련 문서: `docs/stack.md`
- 기존 에디터 스펙: `docs/spec/20260406-resume-editor.md`, `docs/spec/20260406-resume-file-save-fix.md`
- `gray-matter` 공식 문서: https://github.com/jonschlinkert/gray-matter
