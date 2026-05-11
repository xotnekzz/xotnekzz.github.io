---
name: homepage-content
description: "개인 홈페이지 콘텐츠 제작 오케스트레이터. 블로그 포스팅 작성, 포트폴리오 케이스 스터디 추가, 이력서 업데이트 등 모든 문서·콘텐츠 제작 요청에 반드시 이 스킬을 사용할 것. '블로그 써줘', '블로그 포스팅', '포트폴리오 추가', '포트폴리오 작성', '이력서 업데이트', '이력서 추가', '이력서 수정', '글 작성', '포스트 만들어', '케이스 스터디', '경력 추가' 등의 키워드가 포함된 요청이면 이 스킬을 트리거한다. 콘텐츠 수정, 다시 작성, 보완 요청도 처리한다."
---

# 홈페이지 콘텐츠 제작 오케스트레이터

블로그 포스팅, 포트폴리오 케이스 스터디, 이력서 세 가지 콘텐츠 유형을 작성하거나 업데이트한다.

## 실행 모드

**서브에이전트 단독 실행** (content-writer 에이전트)
- 콘텐츠 유형에 따라 작성 방식이 다르지만, 단일 에이전트가 처리
- 리서치가 필요하면 에이전트 내부에서 WebSearch로 보강

---

## Phase 0: 요청 분석

사용자 요청에서 다음을 파악한다:

| 항목 | 파악 방법 |
|------|----------|
| 콘텐츠 유형 | 블로그 / 포트폴리오 / 이력서 |
| 주제/키워드 | 사용자가 제공한 소재 |
| 카테고리 | DataEngineering / AnalyticsEngineering / AIEnginerring / Governance 등 |
| 기존 파일 유무 | 수정인지 신규 작성인지 |
| 참고 자료 | 사용자가 링크/메모/초안을 제공했는지 |

파악이 불충분하면 단일 질문으로 핵심 정보를 수집한다.

---

## Phase 1: 콘텐츠 작성

`.claude/agents/content-writer.md`의 에이전트를 실행한다.

**Agent 호출:**
```
Agent(
  subagent_type: "general-purpose",
  model: "opus",
  prompt: [content-writer.md 내용] + {
    콘텐츠 유형: 블로그|포트폴리오|이력서,
    주제/소재: 사용자 제공 정보,
    카테고리: 해당 카테고리,
    참고 자료: 사용자 제공 링크/메모,
    기존 파일 경로: (수정인 경우),
    오늘 날짜: YYYY-MM-DD
  }
)
```

**유형별 출력:**
- 블로그: `src/content/posts/{Category}/{slug}.md`
- 포트폴리오: `src/content/portfolio/{Category}/{title}.md`
- 이력서: `src/data/resume.md` (기존 파일 수정)

---

## Phase 2: 결과 보고

사용자에게 다음 정보를 보고한다:
- 생성/수정된 파일 경로
- 콘텐츠 제목 및 핵심 내용 요약
- 수정이 필요하면 구체적으로 요청하도록 안내

---

## 콘텐츠 유형별 가이드라인 요약

### 블로그 포스팅
```
카테고리: DataEngineering | AnalyticsEngineering | dev
위치: src/content/posts/{Category}/{slug}.md
프론트매터 필수: title, description, date, tags, featured
슬러그: 영문 소문자 + 하이픈
```

### 포트폴리오 케이스 스터디
```
카테고리: AIEnginerring | DataEngineering | AnalyticsEnginering | Governance
위치: src/content/portfolio/{Category}/{파일명}.md
프론트매터 필수: title, description, date, tags, featured
섹션: Background → Solution → Results → Lessons
파일명: 한국어 가능 (예: "사내 통합 AI 에이전트 플랫폼 구축.md")
```

### 이력서 업데이트
```
위치: src/data/resume.md
구조: personal / experiences / skills / education
원칙: 기존 YAML 패턴 유지, bullets는 동사+수치 형식
```

---

## 자주 쓰는 패턴

**블로그 포스팅 요청 예시:**
"Apache Airflow DAG 팩토리 패턴에 대해 블로그 포스팅 써줘"
→ DataEngineering 카테고리, 기술 내용 리서치 + 실무 경험 기반 작성

**포트폴리오 추가 요청 예시:**
"SeaweedFS 기반 분산 스토리지 구축 프로젝트를 포트폴리오에 추가해줘"
→ DataEngineering 카테고리, Background/Solution/Results 구조로 작성

**이력서 업데이트 요청 예시:**
"이력서에 MCP 서버 개발 경험 bullet 추가해줘"
→ `src/data/resume.md` 열어서 AI Engineering 프로젝트 bullets에 추가

---

## 에러 핸들링

| 상황 | 처리 방법 |
|------|----------|
| 소재 부족 | 단일 질문으로 핵심 정보 수집 (주제, 기간, 핵심 성과) |
| 카테고리 불명확 | 기존 파일들 확인 후 가장 유사한 카테고리 선택 |
| 이력서 YAML 충돌 | 기존 파일 전체 읽기 후 신중하게 Edit |
| 파일명 한글/공백 | 포트폴리오는 한글 파일명 허용, 블로그는 영문 슬러그 사용 |

---

## 테스트 시나리오

**정상 흐름:**
"Apache Doris OLAP 아키텍처에 대한 블로그 포스팅 작성해줘"
→ DataEngineering 카테고리 → content-writer가 기술 내용 작성 → `src/content/posts/DataEngineering/apache-doris-olap-architecture.md` 생성

**이력서 업데이트:**
"이력서에 SeaweedFS 분산 파일 시스템 도입 bullet 추가해줘"
→ `src/data/resume.md` 읽기 → 데이터 인프라 프로젝트 bullets에 추가 → 파일 수정

**수정 요청:**
"방금 쓴 포트폴리오 글에 결과 수치가 빠졌어. 쿼리 응답 50배 단축이라는 내용 추가해줘"
→ 기존 파일 경로 확인 → Edit으로 Results 섹션 수정
