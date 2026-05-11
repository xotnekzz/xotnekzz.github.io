---
command: /new-track
description: 새 트랙 생성 — 스펙 + 플랜 + sprint-contract 작성 (구현은 안 함). /implement로 이어짐.
argument-hint: <짧은 설명>
---

# /new-track

트랙 생성 = 스펙 + 플랜 + 계약. **Planner 서브에이전트**에 위임한다.

## 단계

1. 설명 슬러그화 → `<track>` (소문자, 하이픈, ≤30자)
2. `ingest-spec` 스킬 로직으로 `docs/product-specs/<track>.md` 작성
3. **서브에이전트 호출**: Claude Code의 `Task` 툴(다른 이름: `Agent`)을
   `subagent_type="planner"`로 호출. 프롬프트에 track 슬러그와 스펙 경로 전달.
   Planner가 격리된 컨텍스트에서 다음을 생성:
   - `.harness/tracks/active/<track>/plan.md`
   - `.harness/tracks/active/<track>/sprint-contract.md`
4. 반환 메시지 확인 (`PLAN WRITTEN:` 라인)
5. `docs/product-specs/index.md`의 `## 활성`에 트랙 추가
6. 출력:
   ```
   TRACK CREATED: <track>
   spec: docs/product-specs/<track>.md
   plan: .harness/tracks/active/<track>/plan.md
   NEXT: /implement <track>
   ```

## 왜 서브에이전트인가

Planner의 컨텍스트를 메인 대화와 분리해 스펙/플랜 품질을 높이고 토큰 예산을
격리한다. 서브에이전트 미지원 CLI(Codex/Gemini)에서는 단일 컨텍스트 롤플레이로
자동 degrade — 어댑터가 분기한다.

## 가드레일

- 기존 활성 트랙과 슬러그 충돌 시 `-v2` 추가
- 여기서 구현 시작 금지 — Planner는 스펙/플랜만 작성
