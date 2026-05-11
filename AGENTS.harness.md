# {{PROJECT_NAME}} — 에이전트 목차

> **이 파일은 목차이지 백과사전이 아니다.** ≤100줄. `.harness/linters/agents_md_size.py`
> 로 하드캡. 링크는 현재 작업에 관련될 때만 따라간다.

## 1. 방향 잡기

- **하네스 파일 지도 (어느 파일이 누구 소유?)** → [HARNESS_MAP.md](HARNESS_MAP.md)
- **사용 매뉴얼 (사람용)** → [docs/USAGE.md](docs/USAGE.md)
- **아키텍처 맵** → [ARCHITECTURE.md](ARCHITECTURE.md)
- **운영 원칙(핵심 신념)** → [docs/design-docs/core-beliefs.md](docs/design-docs/core-beliefs.md)
- **설계 문서 색인** → [docs/design-docs/index.md](docs/design-docs/index.md)
- **기술 부채 & 드리프트** → [.harness/tracks/tech-debt-tracker.md](.harness/tracks/tech-debt-tracker.md)

## 2. 진행 중인 작업

- **실행 중 계획** → [.harness/tracks/active/](.harness/tracks/active/)
- **제품 스펙** → [docs/product-specs/index.md](docs/product-specs/index.md)
- **완료된 계획(학습 자료)** → [.harness/tracks/completed/](.harness/tracks/completed/)

## 3. 워크플로 — 슬래시 커맨드, 파일 핸드오프

수동 (사람 리뷰 지점 포함):
1. `/setup` — 제품/스택/워크플로 문서 초기화 (최초 1회)
2. `/new-track <설명>` — `docs/product-specs/<track>.md` + `.harness/tracks/active/<track>/plan.md` 생성
3. `/implement <track>` — plan 실행, 상태는 디스크에 저장

자동 (Ralph 루프):
- `/autopilot <설명|트랙>` — 요청→계획→개발→검증→보고 자동 반복. `report.md` 생성.

커맨드 프롬프트: [.harness/commands/](.harness/commands/)

## 4. 3-에이전트 파이프라인

| 역할 | 프롬프트 | 계약 |
|---|---|---|
| Planner | [planner.md](.harness/agents/planner.md) | spec + plan 작성 |
| Implementer | [implementer.md](.harness/agents/implementer.md) | sprint-contract.md 협상 후 실행 |
| Evaluator | [evaluator.md](.harness/agents/evaluator.md) | 코드 반영 전 승인 게이트 |

## 5. 가드레일 (기계적 강제)

| 규칙 | 린터 |
|---|---|
| 레이어 순서: types → config → repo → service → runtime → ui | `.harness/linters/arch_layers.py` |
| 문서 ↔ 코드 드리프트 | `.harness/linters/doc_freshness.py` |
| `AGENTS.md` ≤ 100줄 | `.harness/linters/agents_md_size.py` |
| 메모리 프런트매터 스키마 | `.harness/linters/memory_schema.py` |

차단/경고 레벨 구분: [.harness/config.yaml](.harness/config.yaml) `guardrails.block_on` / `warn_on`.

## 6. Memory vs Docs — 라우팅

| 종류 | 저장 위치 |
|---|---|
| 사용자 프로필/선호 | `memory/user_*.md` |
| 교정 피드백 | `memory/feedback_*.md` |
| 장기 프로젝트 상태 | `memory/project_*.md` |
| 외부 시스템 포인터 | `memory/reference_*.md` |
| 트랙 완료 후 학습 | `.harness/tracks/completed/<track>/lessons.md` |
| 아키텍처 결정 | `docs/design-docs/*.md` |

규칙: **개인/세션 → `memory/`**, **팀 공유 → `docs/`**

## 7. 스타일 & 신뢰성 포인터

- [docs/DESIGN.md](docs/DESIGN.md)
- [docs/QUALITY_SCORE.md](docs/QUALITY_SCORE.md)
- [docs/RELIABILITY.md](docs/RELIABILITY.md)
- [docs/SECURITY.md](docs/SECURITY.md)

## 8. 엔트로피 GC

`doc-gardener`가 주간 실행(`.github/workflows/doc-gardener.yml`). 상세: [.harness/agents/doc-gardener.md](.harness/agents/doc-gardener.md). 주당 PR 상한 5개, 기본 dry-run.

## 9. 편집 전 체크

1. 아키텍처 레이어 OK? → `.harness/linters/arch_layers.py`
2. 관련 MOC 읽었나? (`user-prompt-submit` 훅이 주입했을 수 있음)
3. 긴 세션? → `.harness/skills/context-reset/SKILL.md`로 핸드오프 작성
