# 기여 가이드

## 원칙

- **기계적 강제 우선** — 새 규칙은 문장이 아니라 린터/훅으로
- **AGENTS.md는 목차** — 상세 설명은 링크 대상 문서에
- **설계 변경은 ADR** — `docs/design-docs/`에 결정 기록 추가

## 추가 위치

| 추가하는 것 | 위치 | 비고 |
|---|---|---|
| 린터 | `.harness/linters/` | `harness lint`에 등록 |
| CLI 어댑터 | `.harness/adapters/<cli>/compile.sh` | 규약 준수 |
| 에이전트 | `.harness/agents/<name>.md` | AGENTS.md §4에 한 줄 등록 |
| 스킬 (프로젝트) | `.harness/skills/<name>/SKILL.md` | [외부 스킬 추가](USAGE.md) |
| 커맨드 | `.harness/commands/<name>.md` | 어댑터가 컴파일 |
| 설계 결정 | `docs/design-docs/<adr>.md` | `index.md` 갱신 |

## 레이어 규칙 변경

`.harness/config.yaml`의 `guardrails.layer_order` 수정.

## PR 전 로컬 체크

```bash
harness lint
pre-commit run --all-files
```

## 커밋 스타일

- `feat:` `fix:` `docs:` `refactor:` 등 prefix 권장
- 커밋 메시지는 **왜**를 설명 (무엇은 diff가 말해줌)
