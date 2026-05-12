# 아키텍처 — blog

도메인/레이어 맵. 에이전트는 편집 전에 이 문서를 읽고 올바른 레이어를 찾는다.

## 레이어 순서 (강제)

```
types   →  config  →  repo  →  service  →  runtime  →  ui
```

- `types`: 순수 데이터 형태, I/O 없음
- `config`: 정적 설정, 환경 변수 파싱
- `repo`: 데이터 접근 (DB, 파일시스템, 외부 API 클라이언트)
- `service`: 도메인 로직, repo 조합
- `runtime`: 오케스트레이션, 스케줄러, 진입점
- `ui`: CLI, 웹, TUI — 얇은 층, service로 위임

**규칙**: import는 **아래 방향으로만** 흐른다. `.harness/linters/arch_layers.py`로 강제.

## 모듈 (프로젝트별로 채움)

| 모듈 | 레이어 | 경로 | 비고 |
|---|---|---|---|
| 모듈 | 레이어 | 경로 | 비고 |
|---|---|---|---|
| _예시_ | service | `src/billing/` | — |

## 확장 포인트

- 레이어 추가 → `.harness/config.yaml`의 `guardrails.layer_order` 수정
- 언어 추가 → `.harness/linters/plugins/`에 플러그인 추가

## 횡단 관심사

- 로깅: 구조화 로깅만 — [.harness/docs/RELIABILITY.md](.harness/docs/RELIABILITY.md)
- 시크릿: 커밋 금지 — [.harness/docs/SECURITY.md](.harness/docs/SECURITY.md)
- 에러: 절대 무음으로 삼키지 않음 — 전파하거나 컨텍스트와 함께 로그

## 파일 소유권

"이 파일은 하네스가 쓰는가, 내가 쓰는가?"

| 영역 | 경로 | 소유 |
|---|---|---|
| 에이전트 프롬프트 | `.harness/agents/*.md` | 하네스 |
| 커맨드 정의 | `.harness/commands.md` | 하네스 |
| 훅 | `.harness/hooks/**` | 하네스 |
| 린터 | `.harness/linters/` | 하네스 |
| 트랙 (진행) | `.harness/tracks/<track>.md` | 에이전트 |
| 트랙 (완료) | `.harness/tracks/done/<track>.md` | 에이전트 |
| 트랙 인덱스 | `.harness/Track.md` | 에이전트 |
| 설계 문서 | `.harness/docs/design-docs/` | 사람 |
| 컨벤션 | `.harness/docs/DESIGN.md` 등 | 사람 |
| CLI 진입점 | `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` | 하네스 (루트 고정) |

저장 위치 결정 플로우:
```
에이전트가 자동 생성?
  ├─ 예 → .harness/tracks/
  └─ 아니오(사람이 씀) → .harness/docs/
```
