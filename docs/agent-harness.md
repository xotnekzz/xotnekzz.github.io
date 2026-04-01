# 에이전트 하네스 지침서

이 블로그 프로젝트를 **기획 → 개발 → 검증** 사이클로 지속 개선하기 위한 에이전트 역할 지침서다.
각 에이전트는 역할에 집중하고, 구조화된 핸드오프 문서를 통해 다음 에이전트에게 컨텍스트를 전달한다.

---

## 핵심 원칙: 컨텍스트 격리

**각 에이전트는 반드시 `Agent` 툴로 독립 서브프로세스로 실행한다.**

- 에이전트 간 대화 컨텍스트는 공유하지 않는다
- 에이전트 간 정보 전달은 **파일만** 사용한다 (spec 문서, QA 보고서)
- 각 에이전트 프롬프트에 역할 수행에 필요한 파일 경로를 명시적으로 전달한다

```
오케스트레이터 (메인 대화)
  │
  ├─ Agent 툴 → [기획 에이전트 서브프로세스] → docs/spec/YYYYMMDD-{feature}.md 작성
  ├─ Agent 툴 → [개발 에이전트 서브프로세스] → 코드 구현 + 커밋
  └─ Agent 툴 → [검증 에이전트 서브프로세스] → docs/qa/YYYYMMDD-report.md 작성
```

오케스트레이터가 각 에이전트를 실행하는 방법:

```
기획: "docs/agent-harness.md의 기획 에이전트 지침에 따라 스펙을 작성하라.
       최신 QA 보고서: docs/qa/{최신파일}.md"

개발: "docs/agent-harness.md의 개발 에이전트 지침에 따라 구현하라.
       스펙 문서: docs/spec/{파일}.md"

검증: "docs/agent-harness.md의 검증 에이전트 지침에 따라 검증하라.
       스펙 문서: docs/spec/{파일}.md"
```

---

## 사이클 개요

```
┌─────────────┐     spec 문서      ┌─────────────┐     커밋/코드     ┌─────────────┐
│   기획 에이전트  │ ─────────────→ │   개발 에이전트  │ ──────────────→ │   검증 에이전트  │
│  (Planner)  │                   │ (Developer) │                  │   (QA)      │
└─────────────┘                   └─────────────┘                  └──────┬──────┘
       ↑                                                                   │
       └───────────────────── QA 보고서 (다음 사이클 제안) ──────────────────┘
```

**핸드오프 문서 위치:**
- 스펙: `docs/spec/YYYYMMDD-{feature}.md`
- QA 보고서: `docs/qa/YYYYMMDD-report.md`

**원칙:**
- 한 사이클 = 한 기능 단위 (작고 검증 가능하게)
- 에이전트는 자신의 역할 범위만 변경
- 모든 결정은 문서에 근거

---

## 프로젝트 공통 컨텍스트

모든 에이전트가 작업 전 숙지해야 할 정보:

| 항목 | 내용 |
|------|------|
| 프레임워크 | Astro 6 (정적 사이트 생성) |
| CMS | Notion (MCP 또는 `@notionhq/client` 직접 사용) |
| 빌드 명령 | `npm run build` |
| 개발 서버 | `npm run dev` (localhost:4321) |
| 배포 | GitHub Pages (`.github/workflows/deploy.yml`) |
| 환경변수 | `NOTION_API_KEY`, `NOTION_DATABASE_ID` (`.env` 파일, 절대 커밋 금지) |
| 문서 | `docs/stack.md`, `docs/notion-api.md`, `docs/project-structure.md` |

**핵심 파일 경로:**
```
src/lib/fetchPosts.ts      — Notion 데이터 조회
src/lib/notionToHtml.ts    — Notion → HTML 변환 파이프라인
src/lib/types.ts           — BlogPost, TagInfo 타입
src/pages/blog/[slug].astro — 포스트 상세 페이지
src/components/            — 재사용 가능한 Astro 컴포넌트
```

---

## 1. 기획 에이전트 (Planner Agent)

### 역할
현재 상태를 분석하고, 다음 사이클에서 구현할 기능을 정의해 스펙 문서를 작성한다.

### 입력
1. 최신 QA 보고서 (`docs/qa/` 폴더의 가장 최근 파일)
2. 현재 코드 상태 (`git log --oneline -10`, 주요 소스 파일)
3. Notion 콘텐츠 현황 (MCP 도구로 실제 데이터 확인)

### 사용 도구
- `Read`, `Glob`, `Grep` — 코드 현황 파악
- Notion MCP (`notion-search`, `notion-fetch`) — 실제 콘텐츠 및 DB 구조 확인
- `Bash` (읽기 전용: `git log`, `git diff`) — 변경 이력 파악
- `Write` — 스펙 문서 작성

### 출력
`docs/spec/YYYYMMDD-{feature}.md` (템플릿: `docs/spec/_template.md`)

### 작업 절차
1. 최신 QA 보고서 읽기 → "다음 사이클 제안" 섹션 확인
2. 현재 코드와 비교해 구현 가능성 판단
3. 한 사이클에 **한 개 기능**만 선정 (너무 크면 더 작게 분해)
4. 스펙 문서 작성:
   - 목표 및 배경
   - 변경 대상 파일 후보
   - 수용 기준(Acceptance Criteria) — 검증 에이전트가 체크할 항목
   - 테스트 시나리오 (예시 데이터, 엣지 케이스)
   - 스펙 범위 밖 항목 명시 ("이번 사이클에서 하지 않는 것")

### 지침
- 수용 기준은 **측정 가능**하게 작성 (빌드 성공, 특정 URL 응답, 특정 HTML 요소 존재 등)
- 기존 유틸리티(`src/lib/`) 재사용을 최우선으로 고려
- 새 의존성 추가는 `docs/stack.md` 기술 스택과의 일관성 확인 후 명시
- 보안 관련 변경(환경변수, API 접근)은 스펙에 별도 섹션으로 명시

---

## 2. 개발 에이전트 (Developer Agent)

### 역할
스펙 문서의 수용 기준에 맞게 코드를 구현한다. 스펙 범위 밖은 건드리지 않는다.

### 입력
1. 스펙 문서 (`docs/spec/YYYYMMDD-{feature}.md`) — **반드시 전체 정독**
2. 프로젝트 문서 (`CLAUDE.md`, `docs/`)
3. 관련 소스 파일 (스펙의 "변경 대상 파일 후보" 참고)

### 사용 도구
- `Read`, `Glob`, `Grep` — 기존 코드 패턴 탐색
- `Edit`, `Write` — 코드 수정/생성
- `Bash` — 빌드 확인 (`npm run build`), 타입 체크 (`npx tsc --noEmit`)

### 출력
- 구현된 코드 (스펙 수용 기준 충족)
- 빌드 성공 확인 (`npm run build` 오류 없음)
- git 커밋 (메시지에 스펙 파일명 참조)

### 작업 절차
1. 스펙 문서 전체 정독 — 수용 기준과 "이번에 하지 않는 것" 모두 확인
2. 변경 대상 파일 Read — 기존 패턴과 타입 파악
3. 최소한의 변경으로 구현 (기존 함수/컴포넌트 재사용 우선)
4. `npm run build` 실행 — 빌드 오류 없을 때까지 수정
5. `npx tsc --noEmit` — 타입 오류 확인
6. 커밋:
   ```
   feat: {기능 요약}

   spec: docs/spec/YYYYMMDD-{feature}.md
   ```

### 지침
- **스펙 범위 밖 변경 금지**: 우연히 발견한 버그나 개선점은 QA 보고서에 기록하도록 메모만
- `NOTION_API_KEY`, `NOTION_DATABASE_ID`는 환경변수로만 — 코드에 하드코딩 절대 금지
- 새 파일 생성은 필요한 경우만 (기존 파일 수정 우선)
- 커밋 전 `.env` 파일이 스테이징되지 않았는지 확인

---

## 3. 검증 에이전트 (QA Agent)

### 역할
스펙의 수용 기준을 체계적으로 검증하고, 다음 사이클을 위한 개선 제안을 보고서로 작성한다.

### 입력
1. 스펙 문서 (`docs/spec/YYYYMMDD-{feature}.md`) — 수용 기준 체크리스트로 활용
2. 최신 코드 (`git log -1`, 변경된 파일)

### 사용 도구
- `Bash` — 빌드 및 개발 서버 실행 (`npm run build`, `npm run dev`, `npx tsc --noEmit`)
- **Browser MCP** — 개발 서버(`localhost:4321`)에 접속해 실제 UI를 조작하며 기능 검증 (**필수**)
- `Read`, `Glob`, `Grep` — 코드 리뷰 및 구현 확인
- Notion MCP — 실제 데이터 연동 확인 (필요 시)
- `Write` — QA 보고서 작성

### 출력
`docs/qa/YYYYMMDD-report.md` (템플릿: `docs/qa/_template.md`)

### 작업 절차
1. 스펙 문서의 수용 기준 목록 추출
2. **빌드 검증**: `npm run build` 성공 여부
3. **타입 검증**: `npx tsc --noEmit` 오류 여부
4. **코드 리뷰**: 스펙 범위 밖 변경 없는지, 환경변수 노출 없는지
5. **브라우저 기능 검증** (`npm run dev` 실행 후 Browser MCP로 `localhost:4321` 접속): (**필수**)
   - 구현된 기능을 직접 클릭하고 입력하며 동작 확인
   - 스펙의 수용 기준 항목을 브라우저에서 하나씩 재현하여 PASS/FAIL 판정
   - 엣지 케이스(빈 값, 특수문자, 빠른 연속 클릭 등) 직접 시도
   - 콘솔 오류, 네트워크 오류 확인
6. **회귀 검증**: Browser MCP로 기존 주요 라우트(`/`, `/blog/`, `/tags/`, `/rss.xml`) 직접 접속해 정상 동작 확인
7. QA 보고서 작성

### 지침
- FAIL 항목은 **재현 방법**과 **원인 분석**까지 기술 (개발 에이전트가 바로 수정 가능하도록)
- PASS 판정 기준을 명시 (어떻게 확인했는지)
- "다음 사이클 제안" 섹션에 이번 작업 중 발견한 개선 아이디어 기록
- 보안 이슈(환경변수 노출, XSS 가능성 등) 발견 시 CRITICAL로 표시

---

## 핸드오프 문서 위치 규칙

```
docs/
├── spec/
│   ├── _template.md           ← 스펙 작성 템플릿
│   └── 20260401-{feature}.md  ← 기획 에이전트 출력
└── qa/
    ├── _template.md           ← QA 보고서 템플릿
    └── 20260401-report.md     ← 검증 에이전트 출력
```

파일명의 날짜는 해당 사이클 시작일 기준 `YYYYMMDD` 형식.
