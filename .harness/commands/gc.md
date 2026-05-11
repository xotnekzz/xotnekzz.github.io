---
command: /gc
description: doc-gardener 수동 실행 — 문서/코드 드리프트, 고아 문서, 미사용 MCP를 스캔. 기본 dry-run.
argument-hint: [--apply] [--area <path>]
---

# /gc

`doc-gardener` 에이전트 수동 호출 (보통은 cron으로 실행).

## 인자

- `--apply` — 실제 PR 생성 (기본: dry-run)
- `--area <path>` — 범위 제한

## 단계

1. `.harness/agents/doc-gardener.md` 로드
2. 주간 체크리스트 실행
3. `--apply`면 `auto-gc` 라벨 PR 생성 (주당 5개 캡, 24시간 쿨다운 존중)
4. 요약 출력

## 안전

- 사람이 작성한 PR의 CI 안에서는 `--apply` 모드 실행 금지
- 최근 7일 내 사람이 수정한 파일은 건드리지 않음
