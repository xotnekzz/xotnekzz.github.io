---
name: context-reset
description: 새 에이전트 세션(모든 CLI/모델)이 작업을 재개할 수 있도록 핸드오프 아티팩트 작성
---

# context-reset

## 호출 시점

- 세션이 컨텍스트 한계에 접근
- 다른 모델/CLI로 넘기기 직전
- 활성 트랙 상태에서 `stop` 훅 실행

## 출력

`.harness/tracks/active/<track>/handoff.md` 작성:

```markdown
---
track: <slug>
generated: <ISO datetime>
from_model: <모델명 또는 "unknown">
---

## 상태
- 플랜 진행: <N>/<M> 체크박스 완료
- 마지막 터치 파일: <경로>
- 마지막 테스트 실행: <pass|fail|skipped>

## 미해결 질문
- ...

## 다음 액션
- plan.md의 다음 미체크 박스 그대로: "<text>"

## 컨텍스트 힌트
- 관련 MOC: [...]
- 먼저 재-읽을 파일: [...]
```

## 계약

새로 시작하는 모든 에이전트는 `handoff.md` + `plan.md` + `sprint-contract.md`만
읽고 작업을 이어갈 수 있어야 한다. 채팅 복기 불필요.
