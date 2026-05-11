# 설계 문서 — MOC (Map of Content)

에이전트는 작업에 필요한 문서만 읽는다.

- [core-beliefs.md](core-beliefs.md) — 에이전트 운영 6대 원칙

## 설계 문서 추가 방법

1. `docs/design-docs/<주제>.md` 작성
2. 이 파일에 한 줄 링크 + 짧은 훅 추가
3. `.harness/linters/doc_freshness.py`가 코드와의 드리프트 감지

## 컨벤션

- 문서당 ≤500줄 (린터 경고)
- 첫 섹션: "결정(Decision):"과 "이유(Why):"
- 코드 심볼 링크는 ``[symbol](path/to/file.py#Lnn)`` 형식
