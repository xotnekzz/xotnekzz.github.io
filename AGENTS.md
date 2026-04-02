# AGENTS.md — 에이전트 하네스 오케스트레이터 가이드

이 프로젝트는 **기획 → 개발 → 검증** 3-에이전트 사이클로 운영된다.
각 에이전트는 `Agent` 툴로 독립 서브프로세스로 실행하며, 파일을 통해서만 컨텍스트를 전달한다.

---

## 아키텍처

```
오케스트레이터 (메인 대화)
  │
  ├─ Agent 툴 → [기획 에이전트]  → docs/spec/YYYYMMDD-{feature}.md
  ├─ Agent 툴 → [개발 에이전트]  → 코드 구현 + git 커밋
  └─ Agent 툴 → [검증 에이전트] → docs/qa/YYYYMMDD-report.md
```

**핵심 원칙:**
- 에이전트 간 대화 컨텍스트 공유 없음 — 정보는 **파일로만** 전달
- 각 사이클 = 한 기능 단위 (작고 검증 가능하게)
- 각 에이전트는 자신의 역할 범위 밖은 변경하지 않음

---

## 에이전트 프롬프트 파일

| 에이전트 | 프롬프트 파일 | 역할 |
|----------|--------------|------|
| 기획 (Planner) | `docs/agents/planner.md` | 현황 분석 → 스펙 문서 작성 |
| 개발 (Developer) | `docs/agents/developer.md` | 스펙 기반 코드 구현 + 커밋 |
| 검증 (QA) | `docs/agents/qa.md` | 수용 기준 검증 → QA 보고서 작성 |

---

## 실행 순서

### 1단계 — 기획 에이전트

`docs/agents/planner.md` 내용을 `Agent` 툴 프롬프트로 사용한다.
`{LATEST_QA_REPORT}` 를 `docs/qa/` 폴더의 가장 최근 파일 경로로 교체한다.

```
출력: docs/spec/YYYYMMDD-{feature}.md
```

### 2단계 — 개발 에이전트

`docs/agents/developer.md` 내용을 `Agent` 툴 프롬프트로 사용한다.
`{SPEC_FILE}` 을 1단계에서 생성된 스펙 파일 경로로 교체한다.

```
출력: git 커밋 (스펙 파일 참조 포함)
```

### 3단계 — 검증 에이전트

`docs/agents/qa.md` 내용을 `Agent` 툴 프롬프트로 사용한다.
`{SPEC_FILE}` 을 1단계 스펙 파일 경로로 교체한다.

```
출력: docs/qa/YYYYMMDD-report.md
```

### 다음 사이클

3단계 QA 보고서를 `{LATEST_QA_REPORT}` 로 사용해 1단계 재시작.

---

## 핸드오프 문서 위치

```
docs/
├── agents/
│   ├── planner.md      ← 기획 에이전트 프롬프트
│   ├── developer.md    ← 개발 에이전트 프롬프트
│   └── qa.md           ← 검증 에이전트 프롬프트
├── spec/
│   ├── _template.md
│   └── YYYYMMDD-{feature}.md   ← 기획 에이전트 출력
└── qa/
    ├── _template.md
    └── YYYYMMDD-report.md      ← 검증 에이전트 출력
```
