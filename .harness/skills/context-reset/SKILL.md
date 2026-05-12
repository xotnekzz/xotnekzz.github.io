---
name: context-reset
description: 새 에이전트 세션이 작업을 재개할 수 있도록 트랙 파일 Log에 핸드오프 기록
---

# context-reset

## 호출 시점

- 세션이 컨텍스트 한계에 접근
- 다른 모델/CLI로 넘기기 직전

## 출력

`.harness/tracks/<track>.md`의 `## Log`에 append:

```
<ISO datetime> [handoff] from:<모델명>
  진행: <N>/<M> 체크박스 완료
  다음: <다음 미체크 박스 텍스트>
  힌트: <재개 시 먼저 읽을 것>
```

## 계약

새로 시작하는 에이전트는 트랙 파일(`## Plan` + `## Contract` + `## Log`)만 읽고
작업을 이어갈 수 있어야 한다. 채팅 복기 불필요.
