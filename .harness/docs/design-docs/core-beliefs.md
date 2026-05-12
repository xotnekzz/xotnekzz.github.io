# 핵심 신념 — 에이전트 우선 운영 원칙

6가지 규칙. 린터 심볼이 표시된 곳은 기계적으로 강제된다. 나머지는 문화적
규범이지만 리뷰에서 확인한다.

## 1. 컨텍스트는 파일이다

모든 결정, 계획, 지식은 `docs/`와 `memory/` 하위의 git-versioned markdown에
저장된다. 채팅 로그는 휘발성이다. 내일 중요할 사실이면 파일에 있어야 한다.

*강제 도구*: `.harness/linters/doc_freshness.py`

## 2. `AGENTS.md`는 목차다

≤100줄. 나머지는 전부 링크. 에이전트는 **점진 공개** 원칙으로 동작한다 — 목차를
읽고, 링크 하나 따라가고, 질문이 해소되면 멈춘다.

*강제 도구*: `.harness/linters/agents_md_size.py`

## 3. 점진 공개

각 하위 디렉터리에 `index.md`(MOC)를 둔다. `user-prompt-submit` 훅이 프롬프트의
키워드에 맞는 MOC만 주입한다. 전체 트리를 컨텍스트에 덤프하지 않는다.

## 4. 모델 독립

지시문에 특정 CLI("Claude Code", "Codex")나 모델명을 넣지 않는다. 워크플로
3개 커맨드(`/setup`, `/new-track`, `/implement`)는 **파일**을 생성하므로 어떤
CLI에서도 재개 가능하다. 작업 중 모델 교체 시 = `.harness/tracks/active/<track>/plan.md`
읽고 이어간다.

## 5. 기계적 강제 우선

문장 규칙은 풍화된다. 린터, 훅, pre-commit 검사는 그렇지 않다. 가이드라인을
쓰기 전에 묻는다 — 린터로 표현 가능한가? 가능하면 린터를 만든다.

## 6. 엔트로피 GC

자율성은 드리프트를 낳는다(AI Slope). `doc-gardener`가 주간으로 드리프트를
감지하고 PR을 연다(주당 ≤5건, 기본 dry-run). 데드 코드, 낡은 문서, 연결이
끊긴 MOC은 문장으로 애원하지 않고 기계적으로 청소된다.

---

## 메모리 라우팅 (빠른 참조)

- 세션-개인 사실 → `memory/*.md`
- 팀-공유 지식 → `docs/*.md`
- 트랙 회고 → `.harness/tracks/completed/<track>/lessons.md`
