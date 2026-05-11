---
command: /lint-harness
description: 하네스 자체 건강 검사 — AGENTS.md 사이즈, 메모리 스키마, 레이어, 고아 문서, 미사용 MCP 등 보고만.
---

# /lint-harness

하네스 자체의 건강 검사. 보고만; 변경하지 않음.

## 검사 항목

1. `AGENTS.md` 라인 ≤ 100 (`.harness/linters/agents_md_size.py`)
2. `memory/*.md` 프런트매터 유효 (`.harness/linters/memory_schema.py`)
3. 아키텍처 린터 실행 가능 (`.harness/linters/arch_layers.py --dry-run`)
4. 문서 신선도 (`.harness/linters/doc_freshness.py`)
5. MOC 링크 무결성 — `docs/` 하위 모든 파일이 `index.md`에서 도달 가능
6. `.harness/mcp/servers.json` 중 최근 30일 호출 0건 MCP
7. `docs/product-specs/index.md`에 없는 `.harness/tracks/active/` 고아 트랙

## 출력

```
HARNESS HEALTH: <N passed / M checks>

WARNINGS:
- ...

ERRORS:
- ...
```

에러 없으면 exit 0, 있으면 1.
