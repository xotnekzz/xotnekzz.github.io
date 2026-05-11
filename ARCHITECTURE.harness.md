# 아키텍처 — {{PROJECT_NAME}}

도메인/레이어 최상위 맵. 에이전트는 편집 전에 이 문서를 읽고 올바른 레이어를 찾는다.

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

**규칙**: import는 **아래 방향으로만** 흐른다. `repo` 모듈은 `types`와 `config`를
import할 수 있지만 `service`는 절대 import하지 않는다. `.harness/linters/arch_layers.py`
로 강제.

## 모듈 (프로젝트별로 채움)

| 모듈 | 레이어 | 경로 | 비고 |
|---|---|---|---|
| _예시_ | service | `src/billing/` | — |

## 확장 포인트

- 레이어 추가 → `.harness/config.yaml`의 `guardrails.layer_order` 수정 후 린터 재실행
- 언어 추가 → `.harness/linters/plugins/`에 플러그인 추가

## 횡단 관심사

- 로깅: 구조화 로깅만 사용 — [docs/RELIABILITY.md](docs/RELIABILITY.md) 참고
- 에러: 절대 무음으로 삼키지 않음 — 전파하거나 컨텍스트와 함께 로그
- 시크릿: 커밋 금지 — [docs/SECURITY.md](docs/SECURITY.md) 참고
