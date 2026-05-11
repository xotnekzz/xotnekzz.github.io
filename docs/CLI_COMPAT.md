# CLI 호환성

하네스는 CLI-독립을 원칙으로 한다. 지시문에 CLI/모델명이 박히지 않으며, 어댑터
한 개만 추가하면 새 CLI를 지원할 수 있다.

## 지원 매트릭스

| CLI | 슬래시 커맨드 | 훅 | 자동 로드 |
|---|---|---|---|
| **Claude Code** | ✅ `.claude/commands/` 링크 | ✅ `.claude/settings.json` | `CLAUDE.md` |
| **Codex CLI** | `.codex/commands/` 링크 (프롬프트로 호출) | ⚠️ 미지원 → `daemon/watcher.py` fallback | `AGENTS.md` |
| **Gemini CLI** | `.gemini/commands/` 링크 (프롬프트로 호출, TOML 네이티브 미지원) | ⚠️ 미지원 | `GEMINI.md` |

## 어댑터

- 위치: `.harness/adapters/<cli>/compile.sh`
- 역할: 공통 커맨드/훅 정의를 각 CLI가 이해하는 포맷으로 컴파일
- 교체/추가: `compile.sh` 규약만 지키면 새 CLI 지원 가능

## 재컴파일

```bash
harness sync          # 활성 CLI 전체 재컴파일
harness adapt <cli>   # 특정 CLI만
```

## 훅 미지원 CLI

Codex·Gemini는 네이티브 훅이 없어 `.harness/daemon/watcher.py`가 파일 변경을
감시해 동일한 가드레일을 적용한다.
