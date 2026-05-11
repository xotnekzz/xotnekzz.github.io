---
name: homepage-dev
description: "개인 홈페이지 개발 오케스트레이터. 기능 추가, 버그 수정, UI 개선, 페이지 개발, 컴포넌트 수정 등 모든 코드 개발 요청에 반드시 이 스킬을 사용할 것. '개발해줘', '구현해줘', '추가해줘', '수정해줘', '고쳐줘', '기능', '버그', '페이지 만들어', '컴포넌트', 'feat:', 'fix:' 등의 키워드가 포함된 요청이면 이 스킬을 트리거한다. 다시 실행, 재실행, 이전 결과 개선, 부분 수정 요청도 이 스킬로 처리한다."
---

# 홈페이지 개발 오케스트레이터

개인 홈페이지(Astro 6 + GitHub Pages)의 기능 개발을 위한 3단계 파이프라인을 실행한다.

## 실행 모드

**서브에이전트 파이프라인** (순차 실행)
- Planner → Developer → QA 순으로 각 에이전트를 독립 서브프로세스로 실행
- 에이전트 간 데이터는 **파일로만** 전달 (컨텍스트 공유 없음)

---

## Phase 0: 컨텍스트 확인

실행 전 기존 산출물을 확인하여 실행 모드를 결정한다.

```
docs/spec/ 파일 확인:
  없음                 → 초기 실행 (Full cycle)
  있고 사용자가 특정 기능 요청   → 새 사이클 (신규 스펙 작성)
  있고 "수정" / "다시" 요청    → 부분 재실행 (해당 에이전트만)
```

---

## Phase 1: 기획 (Planner)

`.claude/agents/planner.md`의 에이전트를 실행한다.

**입력으로 전달할 정보:**
- 사용자의 기능 요청 (있을 경우)
- 최신 QA 보고서 경로: `docs/qa/` 폴더의 가장 최신 파일

**Agent 호출:**
```
Agent(
  subagent_type: "general-purpose",
  model: "opus",
  prompt: [planner.md 내용] + 사용자 요청 + 최신 QA 보고서 경로
)
```

**출력:** `docs/spec/YYYYMMDD-{feature}.md` 경로

---

## Phase 2: 개발 (Developer)

`.claude/agents/developer.md`의 에이전트를 실행한다.

**입력으로 전달할 정보:**
- Phase 1에서 생성된 스펙 파일 경로

**Agent 호출:**
```
Agent(
  subagent_type: "general-purpose",
  model: "opus",
  prompt: [developer.md 내용] + SPEC_FILE 경로
)
```

**출력:** 커밋 해시 + 구현 파일 목록

---

## Phase 3: 검증 (QA)

`.claude/agents/qa.md`의 에이전트를 실행한다.

**입력으로 전달할 정보:**
- Phase 1에서 생성된 스펙 파일 경로

**Agent 호출:**
```
Agent(
  subagent_type: "general-purpose",
  model: "opus",
  prompt: [qa.md 내용] + SPEC_FILE 경로
)
```

**출력:** PASS/FAIL/PARTIAL + `docs/qa/YYYYMMDD-report.md` 경로

---

## Phase 4: 결과 요약

사용자에게 다음 정보를 보고한다:
- 스펙 파일 경로
- 구현된 기능 요약 및 커밋 해시
- QA 결과 (PASS/FAIL/PARTIAL)
- FAIL 항목이 있으면 원인 요약 및 다음 사이클 제안

---

## 부분 재실행 가이드

사용자가 "QA만 다시", "개발만 수정", "기획 다시" 요청 시:
- 해당 Phase만 실행
- 이전 스펙 파일을 그대로 사용하거나, 사용자 피드백을 스펙에 반영 후 진행

---

## 에러 핸들링

| 상황 | 처리 방법 |
|------|----------|
| Planner가 스펙 생성 실패 | 사용자에게 기능 요청 명확화 요청 |
| Developer 빌드 실패 | 에러 메시지를 포함해 Developer 1회 재시도 |
| QA FAIL | FAIL 항목을 포함한 보고서 생성, 다음 사이클에서 수정 |
| git 커밋 실패 | `.env` 스테이징 여부 확인 후 재시도 |

---

## 테스트 시나리오

**정상 흐름:**
"블로그 포스트에 읽기 시간 표시 기능 추가해줘"
→ Planner가 스펙 생성 → Developer가 구현 → QA가 브라우저 검증

**부분 재실행:**
"방금 QA 리포트 봤는데 포트폴리오 페이지 회귀 버그가 있어. QA만 다시 해줘"
→ 기존 스펙 파일 사용 → QA만 재실행

**에러 흐름:**
빌드 실패 → Developer에게 에러 로그 전달 → 1회 재시도
