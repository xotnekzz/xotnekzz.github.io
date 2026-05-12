# harness

**CLI-독립 에이전트 하네스 스켈레톤.** 한 번의 `harness init`으로 파일 기반 컨텍스트
시스템, 3-에이전트 파이프라인, 가드레일을 어떤 프로젝트에나 이식한다.
Claude Code · Codex · Gemini CLI 사이를 자유롭게 오간다.

> 에이전트 협업을 **채팅 로그**가 아니라 **git-versioned 마크다운**으로 관리하려는
> 팀을 위한 보일러플레이트.

---

## 왜 하네스인가

대부분의 에이전트 워크플로는 세션에 갇힌다 — 채팅을 닫으면 컨텍스트가 사라지고,
CLI를 바꾸면 지시를 다시 써야 한다. 하네스는 **에이전트가 읽고 쓰는 모든 것을
`.harness/` 아래 파일로 둔다**:

- 계획·계약·진행·평가 → `.harness/tracks/<track>.md` (트랙당 1파일, A4 1장)
- 아키텍처·컨벤션·보안 → `.harness/docs/`
- 트랙 인덱스 → `.harness/Track.md`

훅과 린터가 **기계적으로 강제**한다 — "AGENTS.md 100줄 이하", "레이어 위반 금지"
같은 규칙을 문장으로 적지 않고 스크립트로 차단한다.

---

## 빠른 시작

### 1. 스켈레톤 설치 (1회)

```bash
git clone https://github.com/xotnekzz/harness.git ~/harness
bash ~/harness/install.sh --shell-init
source ~/.zshrc
```

확인:
```bash
harness help
harness where   # 스켈레톤 경로
```

### 2. 프로젝트에 이식

```bash
cd ~/work/my-project
harness init
```

자동 감지:
- 프로젝트 이름 = 디렉터리명
- 모드 = 빈 디렉터리면 `pristine`, 기존 `AGENTS.md`/`src/` 있으면 `adopt`
- 사용할 CLI 어댑터 (claude / codex / gemini, 복수 선택 가능)

```
[harness] 사용할 에이전트 CLI를 선택하세요 (복수 선택 가능):
  1) claude  [detected]
  2) codex
  3) gemini
Enter = 감지된 CLI / 예: "1,3" / 없음: "none"
> _
```

계획 프리뷰 후 `[Y/n]`. 생략: `-y` 또는 `--cli claude,codex`.

### 3. 첫 트랙 실행

에이전트 CLI에서:

```
/setup                              # 최초 1회: 제품/스택 질문
/new-track 사용자 로그인 기능         # 트랙 파일 생성 (Planner)
/implement user-login               # 체크박스 소화 (Implementer → Evaluator)
```

또는 한 방에:
```
/autopilot 로그인 폼에 OTP 추가
```

---

## 구조

이식 후 프로젝트 루트에 추가되는 것:

```
AGENTS.md          ← 에이전트 목차 (≤100줄, CLI가 자동 로드)
CLAUDE.md          ← Claude Code 진입점
GEMINI.md          ← Gemini CLI 진입점
.harness/
  config.yaml      ← 하네스 설정
  ARCHITECTURE.md  ← 레이어 맵 + 파일 소유권
  Track.md         ← 트랙 인덱스
  tracks/
    <track>.md     ← 트랙당 1파일 (Why/Plan/Contract/Log/Verdict)
    done/          ← 완료 트랙
  agents/          ← Planner / Implementer / Evaluator / Reviewer
  commands.md      ← 슬래시 커맨드 정의
  hooks/           ← CLI 훅 (arch 강제, MOC 주입, 핸드오프)
  linters/         ← 가드레일 린터
  docs/            ← 컨벤션 (DESIGN, RELIABILITY, SECURITY 등)
  skills/          ← 재사용 스킬 (autopilot-runner, context-reset 등)
```

**프로젝트 루트에는 CLI가 요구하는 파일만** (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`).
하네스 인프라는 전부 `.harness/` 안에 있어 프로젝트 `docs/`나 기타 파일과 충돌하지 않는다.

---

## 트랙 (작업 단위)

트랙 하나 = 파일 하나. `/new-track`이 생성하는 구조:

```markdown
---
track: login-otp
status: active
started: 2026-05-12
---

## Why
OTP 없이 비밀번호만으로는 보안 기준 미달.

## Plan
- [ ] `service` OtpService.generate() + verify()  · verify: unit test
- [ ] `ui`      로그인 폼 OTP 입력 필드           · verify: e2e smoke

## Contract
성공: 올바른 OTP → 로그인, 틀린 OTP → 401
Evaluator 체크: arch_layers 통과, 테스트 커버리지 ≥ 80%

## Log
2026-05-12 Planner: plan 작성

## Verdict
<!-- APPROVED | CHANGES_REQUESTED | BLOCKED -->
```

A4 1장(≤50줄) 제한. Plan 항목이 넘치면 트랙 분할 신호.

---

## 핵심 원칙

1. **컨텍스트는 파일이다** — 채팅 로그가 아니라 git-versioned 마크다운
2. **AGENTS.md는 목차** — 백과사전 아님 (≤100줄, 린터가 강제)
3. **점진 공개** — 에이전트는 필요한 순간에 필요한 파일만 읽는다
4. **모델 독립** — 지시문에 CLI/모델명이 박히지 않는다
5. **기계적 강제 우선** — 문장 규칙보다 린터/훅
6. **엔트로피 GC** — `doc-gardener`가 주간 드리프트 청소

배경: [.harness/docs/design-docs/core-beliefs.md](.harness/docs/design-docs/core-beliefs.md)

---

## `harness` CLI

```
harness init [옵션]     현재 디렉터리에 하네스 세팅
harness migrate         v1 → v2 구조 마이그레이션
harness sync            스켈레톤 변경 반영 + 어댑터 재컴파일
harness upgrade         git pull + sync
harness adapt <cli>     특정 CLI 어댑터만 재컴파일
harness lint            모든 린터 실행
harness gc [--apply]    doc-gardener 스캔 (기본 dry-run)
harness run <트랙>      /autopilot 래퍼
harness where           스켈레톤 경로
```

---

## 기존 프로젝트 마이그레이션 (v1 → v2)

`docs/`, `memory/`, `ARCHITECTURE.md`가 프로젝트 루트에 있는 구 버전에서 업그레이드:

```bash
harness upgrade              # 스켈레톤 최신화
harness migrate --dry-run    # 변경 미리보기
harness migrate              # 실제 적용
harness lint                 # 결과 확인
```

migrate가 처리하는 것: 트랙 파일 통합(5파일→1파일), 구 하네스 파일 제거,
`ARCHITECTURE.md` 모듈 표 보존, `docs/`·`memory/`의 프로젝트 고유 파일 경고.

---

## 요구사항

- macOS / Linux (Windows는 WSL 권장)
- `python3` ≥ 3.10, `bash`, `git`
- (선택) `pre-commit` — `pipx install pre-commit` 또는 `brew install pre-commit`
- (선택) `gh` CLI — doc-gardener가 PR을 열 때
- 에이전트 CLI: Claude Code / Codex / Gemini CLI 중 하나

---

## 더 읽어보기

- [AGENTS.md](AGENTS.md) — 에이전트 목차 (점진 공개의 출발점)
- [.harness/ARCHITECTURE.md](.harness/ARCHITECTURE.md) — 레이어 규칙 + 파일 소유권
- [.harness/commands.md](.harness/commands.md) — 슬래시 커맨드 정의
- [.harness/docs/CLI_COMPAT.md](.harness/docs/CLI_COMPAT.md) — CLI 호환성·어댑터
- [.harness/docs/CONTRIBUTING.md](.harness/docs/CONTRIBUTING.md) — 기여 규약
- [.harness/docs/design-docs/core-beliefs.md](.harness/docs/design-docs/core-beliefs.md) — 설계 근거

---

## 라이선스

MIT — [LICENSE](LICENSE)
