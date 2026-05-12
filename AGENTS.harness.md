# {{PROJECT_NAME}} — 에이전트 목차

> **이 파일은 목차이지 백과사전이 아니다.** ≤100줄. `.harness/linters/agents_md_size.py`로 하드캡.
> 링크는 현재 작업에 관련될 때만 따라간다.

## 1. 방향 잡기

- **아키텍처 + 파일 소유권** → [.harness/ARCHITECTURE.md](.harness/ARCHITECTURE.md)
- **운영 원칙(핵심 신념)** → [.harness/docs/design-docs/core-beliefs.md](.harness/docs/design-docs/core-beliefs.md)
- **컨벤션(설계·보안·신뢰성)** → [.harness/docs/](.harness/docs/)

## 2. 트랙 (진행 중인 작업)

- **트랙 인덱스** → [.harness/Track.md](.harness/Track.md)
- **트랙 파일** → `.harness/tracks/<track>.md` (A4 1장: Why/Plan/Contract/Log/Verdict)
- **완료 트랙** → `.harness/tracks/done/`

## 3. 워크플로 — 슬래시 커맨드

수동 (사람 리뷰 지점 포함):
1. `/setup` — 프로젝트 컨텍스트 초기화 (최초 1회)
2. `/new-track <설명>` — 트랙 파일 생성 (Planner가 작성)
3. `/implement <track>` — Plan 실행 (Implementer → Evaluator)

자동:
- `/autopilot <설명|트랙>` — 요청→계획→개발→검증 자동 반복

커맨드 정의: [.harness/commands.md](.harness/commands.md)

## 4. 에이전트 파이프라인

| 역할 | 프롬프트 | 소유 |
|---|---|---|
| Planner | [.harness/agents/planner.md](.harness/agents/planner.md) | 트랙 파일 작성 |
| Implementer | [.harness/agents/implementer.md](.harness/agents/implementer.md) | Plan 실행, Log 기록 |
| Evaluator | [.harness/agents/evaluator.md](.harness/agents/evaluator.md) | Verdict 작성 |

## 5. 가드레일 (기계적 강제)

| 규칙 | 린터 |
|---|---|
| 레이어 순서 위반 차단 | `.harness/linters/arch_layers.py` |
| 문서 ↔ 코드 드리프트 경고 | `.harness/linters/doc_freshness.py` |
| `AGENTS.md` ≤ 100줄 | `.harness/linters/agents_md_size.py` |

## 6. 편집 전 체크

1. 아키텍처 레이어 OK? → `.harness/ARCHITECTURE.md`
2. 관련 트랙 읽었나? → `.harness/Track.md`에서 활성 트랙 확인
3. 긴 세션? → `.harness/skills/context-reset/SKILL.md`로 핸드오프 작성
